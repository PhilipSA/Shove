"""Paired MCTS checkpoint screen; optional unequal-budget teacher diagnostic, never a MinMax gate."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import time
import traceback

import numpy as np
import torch

from train import Engine, FORMAT, ROOT, choose_move, load_model, rules_hash, search, snapshot_sources


def opening(engine, fixture, seed, plies):
    observation = engine.ask('reset', fixture=fixture, seed=2 * seed + 1 if fixture.startswith('endgame') else seed)
    rng = np.random.default_rng(seed)
    moves = []
    for _ in range(plies):
        remaining = rng.permutation(len(observation['moves']))
        for index in remaining:
            move = observation['moves'][int(index)]
            after = engine.ask('push', index=int(index))
            if not after['terminal']:
                observation = after
                moves.append(move)
                break
            engine.ask('pop')
        else:
            raise ValueError('No non-terminal opening move; use fewer opening plies')
    return observation, moves


def play_game(engine, candidate, baseline, *, candidate_white, seed,
              simulations, max_plies, opening_plies=8, fixture='initial',
              candidate_cycle_guard=True, baseline_cycle_guard=True,
              candidate_value_scale=1.0, baseline_value_scale=1.0, baseline_simulations=None):
    observation, opening_moves = opening(engine, fixture, seed, opening_plies)
    start = observation
    moves = []
    rng = np.random.default_rng(seed)
    timing = {name: {'moves': 0, 'totalMs': 0.0, 'maxMs': 0.0,
                    'totalCycles': 0, 'totalMaxDepth': 0}
              for name in ('candidate', 'baseline')}
    for _ in range(max_plies):
        role = 'candidate' if (observation['turn'] == 0) == candidate_white else 'baseline'
        model = candidate if role == 'candidate' else baseline
        clock = time.perf_counter()
        stats = {}
        effort = baseline_simulations if role == 'baseline' and baseline_simulations is not None else simulations
        policy = search(engine, model, observation, effort, rng, noise=False,
                        cycle_guard=candidate_cycle_guard if role == 'candidate' else baseline_cycle_guard,
                        value_scale=candidate_value_scale if role == 'candidate' else baseline_value_scale,
                        stats=stats)
        index = choose_move(policy, rng)
        moves.append(observation['moves'][index])
        observation = engine.ask('push', index=index)
        elapsed = (time.perf_counter() - clock) * 1000
        timing[role]['moves'] += 1
        timing[role]['totalCycles'] += stats['cycles']
        timing[role]['totalMaxDepth'] += stats['maxDepth']
        timing[role]['totalMs'] += elapsed
        timing[role]['maxMs'] = max(timing[role]['maxMs'], elapsed)
        if observation['terminal']:
            break
    outcome = ('unfinished' if not observation['terminal'] else
               'draw' if observation['winner'] is None else
               'candidate' if (observation['winner'] == 0) == candidate_white else 'baseline')
    return {'candidateWhite': candidate_white, 'seed': seed, 'outcome': outcome,
            'reason': observation['reason'] or 'plyLimit', 'plies': len(moves),
            'openingMoves': opening_moves, 'start': start, 'moves': moves,
            'final': observation, 'timing': timing}


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--games', type=int, default=20)
    parser.add_argument('--simulations', type=int, default=32)
    parser.add_argument('--baseline-simulations', type=int, help='Headroom diagnostic only; default equals candidate budget')
    parser.add_argument('--candidate-no-cycle-guard', action='store_true')
    parser.add_argument('--baseline-no-cycle-guard', action='store_true')
    parser.add_argument('--candidate-value-scale', type=float, default=1.0)
    parser.add_argument('--baseline-value-scale', type=float, default=1.0)
    parser.add_argument('--max-plies', type=int, default=300)
    parser.add_argument('--opening-plies', type=int, default=8)
    parser.add_argument('--seed', type=int, default=20001)
    parser.add_argument('--fixture', choices=['initial', 'race', 'endgame', 'endgame6', 'endgame8', 'endgame-tactics'], default='initial')
    args = parser.parse_args(argv)
    if args.baseline_simulations is None:
        args.baseline_simulations = args.simulations
    if args.baseline_simulations < 1:
        parser.error('baseline-simulations must be positive')
    if args.games < 2 or args.games % 2 or min(args.simulations, args.max_plies) < 1 or min(args.seed, args.opening_plies) < 0:
        parser.error('games must be positive/even, effort/cap positive, opening-plies/seed nonnegative')
    if not all(0 <= value <= 1 for value in (args.candidate_value_scale, args.baseline_value_scale)):
        parser.error('value scales must be finite and between 0 and 1')
    if args.output.exists():
        parser.error('output already exists; preserve earlier evidence with a new directory')
    if not args.candidate.is_file() or not args.baseline.is_file():
        parser.error('both checkpoint files must exist')
    return args


def main():
    args = parse_args()
    torch.set_num_threads(1)
    # Freeze the files before loading, so another training run cannot change our opponent.
    args.output.mkdir(parents=True)
    manifest = {key: str(value) if isinstance(value, Path) else value
                for key, value in vars(args).items()}
    manifest.update(status='running', format=FORMAT, rulesHash=rules_hash(),
                    sourceHash=snapshot_sources(args.output),
                    engineHash=hashlib.sha256((ROOT / '.dart_tool/alphazero_engine').read_bytes()).hexdigest(),
                    budget=('equal fixed simulations' if args.simulations == args.baseline_simulations else
                            'UNEQUAL simulations: teacher headroom diagnostic, NOT weight improvement'), parallel=1,
                    moveSelection='seeded random max-visit ties',
                    torchVersion=torch.__version__, checkpoints={})
    manifest_path = args.output / 'manifest.json'
    results = []
    engine = None
    try:
        models = {}
        for role in ('candidate', 'baseline'):
            checkpoint = args.output / f'{role}.pt'
            shutil.copyfile(getattr(args, role), checkpoint)
            manifest['checkpoints'][role] = hashlib.sha256(checkpoint.read_bytes()).hexdigest()
            models[role] = load_model(checkpoint)
        manifest_path.write_text(json.dumps(manifest, indent=2))
        engine = Engine(ROOT / '.dart_tool/alphazero_engine')
        with (args.output / 'games.jsonl').open('w') as file:
            for index in range(args.games):
                try:
                    result = play_game(engine, models['candidate'], models['baseline'],
                                       candidate_white=index % 2 == 0, seed=args.seed + index // 2,
                                       simulations=args.simulations, max_plies=args.max_plies,
                                       opening_plies=args.opening_plies, fixture=args.fixture,
                                       candidate_cycle_guard=not args.candidate_no_cycle_guard,
                                       baseline_cycle_guard=not args.baseline_no_cycle_guard,
                                       candidate_value_scale=args.candidate_value_scale,
                                       baseline_value_scale=args.baseline_value_scale,
                                       baseline_simulations=args.baseline_simulations)
                except Exception as error:
                    result = {'outcome': 'error', 'error': str(error), 'stack': traceback.format_exc()}
                result['game'] = index + 1
                results.append(result)
                file.write(json.dumps(result) + '\n')
                file.flush()
                print(json.dumps({key: result[key] for key in ('game', 'outcome', 'reason', 'plies') if key in result}), flush=True)
        manifest['status'] = 'failed' if any(r['outcome'] == 'error' for r in results) else 'completed'
    finally:
        if engine is not None:
            engine.close()
        if manifest['status'] == 'running':
            manifest['status'] = 'failed-or-interrupted'
        manifest_path.write_text(json.dumps(manifest, indent=2))
    outcomes = {name: sum(r['outcome'] == name for r in results)
                for name in ('candidate', 'baseline', 'draw', 'unfinished', 'error')}
    timing = {}
    for role in ('candidate', 'baseline'):
        stats = [r['timing'][role] for r in results if 'timing' in r]
        moves = sum(s['moves'] for s in stats)
        timing[role] = {'moves': moves,
                        'averageMs': sum(s['totalMs'] for s in stats) / moves if moves else 0,
                        'maxMs': max((s['maxMs'] for s in stats), default=0),
                        'cycles': sum(s['totalCycles'] for s in stats),
                        'averageMaxDepth': sum(s['totalMaxDepth'] for s in stats) / moves if moves else 0}
    report = {'outcomes': outcomes, 'timing': timing,
              'budget': manifest['budget'], 'settings': manifest, 'games': results}
    (args.output / 'results.json').write_text(json.dumps(report, indent=2))
    print(json.dumps({'outcomes': outcomes, 'timing': timing}), flush=True)
    print('Exploratory checkpoint screen only. No MinMax comparison or automatic promotion.')
    return 1 if outcomes['error'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
