"""Check frozen Python, native Dart and shipped browser-worker fidelity (not strength)."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np
import torch

from train import Engine, ROOT, load_model, search

# Compiled for VM and JavaScript against the browser worktree's actual player.
DART = r'''
import 'dart:convert';
import 'package:shove/ai/alpha_zero/alpha_zero_ai.dart';
import 'package:shove/ai/alpha_zero/alpha_zero_protocol.dart';
import 'package:shove/ai/alpha_zero/az_network.dart';

Future<List<Map<String, Object?>>> verify(String weights, String casesJson) async {
  final network = DartPolicyValue.fromJson(weights);
  final results = <Map<String, Object?>>[];
  for (final test in jsonDecode(casesJson) as List) {
    final observation = test['observation'];
    final prediction = network.predict(List<int>.from(observation['board']), observation['turn'],
      [for (final move in observation['moves']) List<int>.from(move)]);
    final result = <String, Object?>{'logits': prediction.logits,
      'policy': prediction.policy, 'value': prediction.value};
    if (test['request'] != null) {
      final game = replayAlphaZeroHistory(Map<String, dynamic>.from(test['request']));
      final before = jsonEncode(alphaZeroRequest(game, thinkTime: const Duration(seconds: 60),
        simulations: test['simulations'], seed: 1));
      final ai = AlphaZeroAi('AZ', game.currentPlayersTurn.isWhite,
        network: network, simulations: test['simulations'], seed: 1);
      final move = await ai.makeMove(game);
      if (!game.validateMove(move)) throw StateError('Illegal move');
      if (before != jsonEncode(alphaZeroRequest(game, thinkTime: const Duration(seconds: 60),
        simulations: test['simulations'], seed: 1))) throw StateError('Caller modified');
      final stats = ai.lastSearch!;
      result.addAll({'move': azMove(move), 'actionVisits': stats.actionVisits,
        'policyVisits': stats.policyVisits, 'rootValue': stats.rootValue,
        'cycles': stats.cycles, 'maxDepth': stats.maxDepth, 'simulations': stats.simulations,
        'provenImmediateWin': stats.provenImmediateWin});
    }
    results.add(result);
  }
  return results;
}
'''
VM = r'''
import 'dart:io';
Future<void> main(List<String> args) async {
  stdout.writeln(jsonEncode(await verify(File(args[0]).readAsStringSync(), File(args[1]).readAsStringSync())));
}
'''
JS = r'''
import 'dart:js_interop';
@JS('azWeights') external JSString get weights;
@JS('azCases') external JSString get cases;
@JS('azReport') external void report(JSString text);
Future<void> main() async { report(jsonEncode(await verify(weights.toDart, cases.toDart)).toJS); }
'''
NODE_CORE = r'''
const fs = require('fs');
globalThis.self = globalThis;
globalThis.azWeights = fs.readFileSync(process.argv[3], 'utf8');
globalThis.azCases = fs.readFileSync(process.argv[4], 'utf8');
globalThis.azReport = text => process.stdout.write(text + '\n');
require(process.argv[2]);
'''
NODE_WORKER = r'''
const fs = require('fs');
globalThis.self = globalThis;
let pending;
globalThis.postMessage = text => {
  const message = JSON.parse(text);
  if (message.type === 'error') { if (pending) pending.reject(new Error(message.message)); else throw new Error(message.message); }
  if (message.type === 'result') pending.resolve(message.result);
};
require(process.argv[2]);
const weights = fs.readFileSync(process.argv[3], 'utf8');
const cases = JSON.parse(fs.readFileSync(process.argv[4], 'utf8'));
globalThis.onmessage({data: JSON.stringify({type: 'init', weights})});
(async () => {
  const results = [];
  for (const c of cases) {
    if (!c.request) { results.push(null); continue; }
    const request = {...c.request, simulations:c.simulations, thinkMs:60000};
    const result = await new Promise((resolve, reject) => {
      pending = {resolve, reject};
      globalThis.onmessage({data:JSON.stringify({type:'search', request})});
    });
    results.push(result);
  }
  process.stdout.write(JSON.stringify(results) + '\n');
})().catch(error => { console.error(error); process.exitCode = 1; });
'''


def source(imports, body):
    # Dart directives must precede all declarations.
    lines = body.strip().splitlines()
    directives = [line for line in lines if line.startswith('import ')]
    rest = [line for line in lines if not line.startswith('import ')]
    return '\n'.join(directives) + '\n' + imports + '\n' + '\n'.join(rest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('model', type=Path, help='Frozen export directory with champion.pt/weights.json')
    parser.add_argument('output', type=Path, help='New evidence directory')
    parser.add_argument('--browser-project', type=Path, required=True)
    parser.add_argument('--traces', type=Path, default=ROOT / '.dart_tool/az-long-004')
    parser.add_argument('--dart', type=Path, default=Path.home() / 'develop/flutter/bin/dart')
    args = parser.parse_args()
    if args.output.exists():
        parser.error('output exists; choose a new directory')
    torch.set_num_threads(1)
    model = load_model(args.model / 'champion.pt')
    weights = args.model / 'weights.json'
    metadata = json.loads(weights.read_text())
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    assert metadata['checkpointSha256'] == sha(args.model / 'champion.pt')
    for name, tensor in model.state_dict().items():
        assert np.array_equal(np.array(metadata['tensors'][name]['data'], dtype=np.float32), tensor.numpy().flatten())
    args.output.mkdir(parents=True)
    cases, seen = [], set()
    traces, winning_traces = [], []
    for number in (12, 33, 46, 57):
        path = args.traces / f'round-{number:04}/games.jsonl'
        if not path.exists():
            continue
        records = [json.loads(line) for line in path.read_text().splitlines()]
        trace = next((r for r in records if r.get('fixture') == 'initial' and r['startingTurn'] == 0
                      and r['plies'] > 100 and r['outcome'] == 'unfinished'), None)
        if trace is None:
            trace = next(r for r in records if r.get('fixture') == 'initial' and r['startingTurn'] == 0 and r['plies'] > 80)
        traces.append(trace)
        if number in (12, 57):
            completed = next((r for r in records if r.get('fixture') == 'initial' and r['startingTurn'] == 0
                              and r['outcome'] == 'reachedGoal'), None)
            if completed is not None:
                winning_traces.append(completed)
    traces.extend(winning_traces)
    assert traces, 'No standard-start game traces found'
    engine = Engine(ROOT / '.dart_tool/alphazero_engine')
    try:
        for trace in traces:
            obs = engine.ask('reset')
            prefix = []
            sample = {0, 1, 8, 40, 80, 100, 150, 180, len(trace['moves']) - 1}
            for ply, move in enumerate(trace['moves']):
                identity = json.dumps([obs['board'], obs['turn'], prefix])
                if ply in sample and identity not in seen:
                    seen.add(identity)
                    with torch.no_grad():
                        logits, value = model(obs)
                    for budget in ([32, 256, 1024] if ply in (150, 180) else [32, 256]):
                        stats = {}
                        policy = search(engine, model, obs, budget, np.random.default_rng(1), stats=stats)
                        assert engine.ask('observe') == obs
                        cases.append({'observation': obs, 'logits': logits.tolist(), 'policy': logits.softmax(0).tolist(),
                                      'value': value.item(), 'simulations': budget, 'search': stats,
                                      'searchPolicy': policy.tolist(), 'request': {
                                          'white': 'white', 'black': 'black', 'moves': list(prefix),
                                          'board': obs['board'], 'turn': obs['turn'],
                                          'thinkMs': 60000, 'simulations': budget, 'seed': 1}})
                prefix.append(move)
                obs = engine.ask('push', index=obs['moves'].index(move))
        for turn in (0, 1):
            obs = {'board': [i % 25 for i in range(64)], 'turn': turn,
                   'moves': [[0, 63, 64], [17, 25, 42], [53, 1, 7]]}
            with torch.no_grad():
                logits, value = model(obs)
            cases.append({'observation': obs, 'logits': logits.tolist(), 'value': value.item(), 'policy': logits.softmax(0).tolist()})
    finally:
        engine.close()
    reference = args.output / 'reference.json'
    reference.write_text(json.dumps(cases))
    dart = str(args.dart)
    packages = args.browser_project / '.dart_tool/package_config.json'
    vm_source, js_source = args.output / 'parity_vm.dart', args.output / 'parity_js.dart'
    vm_source.write_text(source('import "dart:io";', DART + VM.replace("import 'dart:io';", '')))
    js_source.write_text(source("import 'dart:js_interop';", DART + JS.replace("import 'dart:js_interop';", '')))
    vm = subprocess.run([dart, f'--packages={packages.resolve()}', str(vm_source.resolve()),
                         str(weights.resolve()), str(reference.resolve())], text=True, capture_output=True, check=True, timeout=180)
    native = json.loads(vm.stdout)
    (args.output / 'native.json').write_text(vm.stdout)
    js_file = args.output / 'parity_js.js'
    subprocess.run([dart, 'compile', 'js', '-O4', f'--packages={packages.resolve()}', str(js_source.resolve()),
                    '-o', str(js_file.resolve())], check=True, timeout=120)
    for name, script in [('javascript-core', NODE_CORE), ('shipped-worker', NODE_WORKER)]:
        helper = args.output / f'{name}.cjs'
        helper.write_text(script)
        entry = js_file if name == 'javascript-core' else args.browser_project / 'web/alpha_zero_worker.js'
        result = subprocess.run(['node', str(helper.resolve()), str(entry.resolve()), str(weights.resolve()), str(reference.resolve())],
                                text=True, capture_output=True, check=True, timeout=180)
        (args.output / f'{name}.json').write_text(result.stdout)
    js_results = json.loads((args.output / 'javascript-core.json').read_text())
    worker_results = json.loads((args.output / 'shipped-worker.json').read_text())
    summaries = {}
    for runtime, results in [('native', native), ('javascript-core', js_results), ('shipped-worker', worker_results)]:
        errors = []
        inference = {'logits': 0.0, 'policy': 0.0, 'value': 0.0}
        exact = changed = ties = searches = compatible = 0
        max_visit_l1 = max_root_error = 0.0
        for index, (case, actual) in enumerate(zip(cases, results, strict=True)):
            if runtime != 'shipped-worker':
                for key in inference:
                    error = float(np.max(np.abs(np.array(case[key]) - np.array(actual[key]))))
                    inference[key] = max(inference[key], error)
                    if error > 2e-5:
                        errors.append(f'{index}: {key} error {error}')
            if 'request' not in case:
                continue
            searches += 1
            expected = case['search']
            budget = case['simulations']
            if actual['simulations'] != budget:
                errors.append(f'{index}: budget not completed')
            for key in ('cycles', 'maxDepth'):
                if actual[key] != expected[key]:
                    errors.append(f'{index}: {key} differs {actual[key]} vs {expected[key]}')
            if actual['provenImmediateWin'] != (expected['policySource'] == 'provenImmediateWin'):
                errors.append(f'{index}: immediate-win override differs')
            root_error = abs(actual['rootValue'] - expected['rootValue'])
            max_root_error = max(max_root_error, root_error)
            if root_error > 0.002:
                errors.append(f'{index}: root value differs {root_error}')
            wanted = actual['move']
            move_index = case['observation']['moves'].index(wanted)
            visits = expected['policyVisits']
            maxima = [i for i, count in enumerate(visits) if count == max(visits)]
            ties += len(maxima) > 1
            compatible += move_index in maxima
            if move_index not in maxima:
                errors.append(f'{index}: selected move not a Python max-visit action')
            if runtime != 'shipped-worker':
                difference = int(np.sum(np.abs(np.array(actual['actionVisits']) - np.array(expected['actionVisits']))))
                max_visit_l1 = max(max_visit_l1, difference)
                exact += difference == 0
                changed += difference != 0
                policy_difference = int(np.sum(np.abs(np.array(actual['policyVisits']) - np.array(expected['policyVisits']))))
                if max(difference, policy_difference) > max(2, int(budget * .01)):
                    errors.append(f'{index}: visit L1 differs {difference}/{budget}; target L1 {policy_difference}')
                if sum(actual['actionVisits']) != budget:
                    errors.append(f'{index}: lost visits')
        summaries[runtime] = {'maxInferenceError': inference if runtime != 'shipped-worker' else None,
                              'searches': searches, 'exactVisits': exact if runtime != 'shipped-worker' else None,
                              'roundoffChangedSearches': changed if runtime != 'shipped-worker' else None,
                              'maxVisitL1': max_visit_l1 if runtime != 'shipped-worker' else None,
                              'pythonMaxVisitMoves': compatible, 'pythonVisitTieCases': ties,
                              'maxRootValueError': max_root_error, 'errors': errors}
    summary = {'checkpointSha256': metadata['checkpointSha256'], 'weightsSha256': sha(weights),
               'workerSha256': sha(args.browser_project / 'web/alpha_zero_worker.js'),
               'nodeVersion': subprocess.check_output(['node', '--version'], text=True).strip(),
               'cases': len(cases), 'uniqueBoards': len({json.dumps(c['observation']['board']) for c in cases}),
               'blackTurnCases': sum(c['observation']['turn'] == 1 for c in cases),
               'stunnedCases': sum(any(v > 12 for v in c['observation']['board']) for c in cases),
               'actorMoveCases': sum(any(m[2] != 64 for m in c['observation']['moves']) for c in cases),
               'cycleCases': sum(c.get('search', {}).get('cycles', 0) > 0 for c in cases),
               'immediateWinCases': sum(c.get('search', {}).get('policySource') == 'provenImmediateWin' for c in cases),
               'results': summaries, 'scope': 'Fixed-budget fidelity, not timed strength; JS executed in Node, not Chrome'}
    (args.output / 'summary.json').write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2))
    if any(s['errors'] for s in summaries.values()):
        raise SystemExit('Runtime parity checks failed; inspect summary.json')


if __name__ == '__main__':
    main()
