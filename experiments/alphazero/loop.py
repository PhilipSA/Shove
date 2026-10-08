"""Bounded, resumable self-play loop. Promotion is experimental only, never into the app."""
import argparse
import copy
import hashlib
import json
import math
import multiprocessing
from pathlib import Path
import time

import numpy as np
import torch

from audit import verify_game
from compare import play_game
from fit import diagnostics
from train import Engine, FORMAT, ROOT, PolicyValue, load_model, rules_hash, self_play, snapshot_sources, train_batch, encode, save_model

FIXTURES = ['initial', 'race', 'endgame', 'endgame6', 'endgame8', 'endgame-tactics']


def promotion_decision(games, threshold=0.55):
    """AlphaGo Zero-style score gate; paired sign test is still reported for README claims.

    Score: win 1, engine draw 0.5, ply-capped 0.5 (no winner either way). Errors invalidate.
    """
    if not games or len(games) % 2:
        raise ValueError('Gate requires color-swapped pairs')
    wins = losses = ties = unresolved = 0
    for first, second in zip(games[::2], games[1::2]):
        if (first['seed'] != second['seed'] or first['start'] != second['start'] or
                first['candidateWhite'] is not True or second['candidateWhite'] is not False):
            raise ValueError('Gate opening/color pairing differs')
        outcomes = [first['outcome'], second['outcome']]
        if any(outcome not in ('candidate', 'baseline', 'draw', 'unfinished') for outcome in outcomes):
            raise ValueError('Errors invalidate promotion')
        if 'unfinished' in outcomes:
            unresolved += 1
        else:
            score = sum(1 if outcome == 'candidate' else 0.5 if outcome == 'draw' else 0 for outcome in outcomes)
            wins += score > 1
            losses += score < 1
            ties += score == 1
    trials = wins + losses + unresolved
    # Worst-case unresolved pairs count against the claim, NOT as fabricated game losses/draws.
    p = sum(math.comb(trials, k) for k in range(wins, trials + 1)) / 2 ** trials if trials else 1.0
    score = sum(1 if g['outcome'] == 'candidate' else 0 if g['outcome'] == 'baseline' else 0.5
                for g in games) / len(games)
    return {'promote': score >= threshold, 'scoreRate': score, 'threshold': threshold,
            'pairWins': wins, 'pairLosses': losses, 'tiedPairs': ties, 'unresolvedPairs': unresolved,
            'worstCaseOneSidedP': p, 'significant': p <= 0.05}


def replay_batch(replay, rng, root_fraction=0):
    count = min(64, len(replay))
    selected = []
    if root_fraction:
        roots = [i for i, ex in enumerate(replay) if ex['observation']['historyLength'] == 0]
        selected = rng.permutation(roots)[:int(count * root_fraction)].tolist()
    used = set(selected)
    selected += [int(i) for i in rng.permutation(len(replay)) if i not in used][:count - len(selected)]
    return [replay[i] for i in selected]


def regression_decision(games):
    # A conservative smoke screen, not a statistical non-inferiority guarantee.
    promotion_decision(games)  # Validate pairing and reject errors.
    counts = {name: sum(game['outcome'] == name for game in games)
              for name in ('candidate', 'baseline', 'draw', 'unfinished')}
    return {'pass': counts['unfinished'] == 0 and counts['candidate'] >= counts['baseline'],
            'outcomes': counts}


# Each worker process owns one Dart engine; PyTorch stays at one thread per process.
_engine = None


def _init_worker():
    global _engine
    torch.set_num_threads(1)
    _engine = Engine(ROOT / '.dart_tool/alphazero_engine')


def _model(weights, local):
    model = PolicyValue(local_policy=local).eval()
    model.load_state_dict(weights)
    return model


def _selfplay_task(task):
    model = _model(task['weights'], task['local'])
    examples, result = self_play(_engine, model, task['simulations'], task['maxPlies'],
                                 np.random.default_rng(task['rngSeed']), task['fixture'], task['turn'],
                                 fixture_seed=task['fixtureSeed'], capped_as_draw=task['cappedAsDraw'])
    verify_game(_engine, task['fixture'], result, examples)
    result['fixture'] = task['fixture']
    return examples, result


def _match_task(task):
    return play_game(_engine, _model(*task['candidate']), _model(*task['baseline']),
                     candidate_white=task['candidateWhite'], seed=task['seed'],
                     simulations=task['simulations'], max_plies=task['maxPlies'],
                     opening_plies=task['openingPlies'], fixture=task['fixture'])


class Runner:
    """Runs tasks in worker processes, or inline for --workers 1 (results always in task order)."""

    def __init__(self, workers):
        if workers > 1:
            self.pool = multiprocessing.get_context('spawn').Pool(workers, initializer=_init_worker)
        else:
            self.pool = None
            _init_worker()

    def map(self, function, tasks):
        return self.pool.imap(function, tasks) if self.pool else map(function, tasks)

    def close(self):
        if self.pool:
            self.pool.terminate()
            self.pool.join()
        elif _engine is not None:
            _engine.close()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group()
    source.add_argument('--checkpoint', type=Path, help='Initial champion, not a fitting-check checkpoint')
    source.add_argument('--resume', type=Path, help='Prior loop state.pt; output must be a NEW directory')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--rounds', type=int, default=2)
    parser.add_argument('--stop-after-hours', type=float, help='Start no new round after this wall-clock time')
    parser.add_argument('--games', type=int, default=4, help='Champion self-play games per round')
    parser.add_argument('--workers', type=int, default=1, help='Parallel self-play/gate processes, one thread each')
    parser.add_argument('--updates', type=int, default=128)
    parser.add_argument('--replay-size', type=int, default=4096)
    parser.add_argument('--local-policy', action='store_true',
                        help='Add the board-aware residual to a loaded legacy learner (fresh models always have it)')
    parser.add_argument('--root-fraction', type=float, default=0,
                        help='Reserve this fraction of each batch for starting decisions, without duplicate samples')
    parser.add_argument('--gate-games', type=int, default=20)
    parser.add_argument('--promote-score', type=float, default=0.55,
                        help='Promote at this gate score rate (AlphaGo Zero: 0.55); 0 always promotes the latest learner')
    parser.add_argument('--simulations', type=int, default=256)
    parser.add_argument('--gate-simulations', type=int, help='Equal budget for both gate players; defaults to training budget')
    parser.add_argument('--max-plies', type=int, default=300)
    parser.add_argument('--capped-as-draw', action='store_true',
                        help='Train ply-capped games with value 0; outcome stays "unfinished" in every report')
    parser.add_argument('--opening-plies', type=int, default=8)
    parser.add_argument('--fixture', choices=FIXTURES, nargs='+', default=['initial'],
                        help='Self-play cycles through these per game; the first one is also the gate fixture')
    parser.add_argument('--regression-fixture', choices=FIXTURES[2:])
    parser.add_argument('--regression-games', type=int, default=20)
    parser.add_argument('--value-loss-weight', type=float, default=1.0)
    parser.add_argument('--weight-decay', type=float, default=1e-4)
    parser.add_argument('--seed', type=int, default=3)
    args = parser.parse_args(argv)
    if args.gate_simulations is None:
        args.gate_simulations = args.simulations
    if args.gate_simulations < 1:
        parser.error('gate-simulations must be positive')
    if min(args.rounds, args.games, args.updates, args.simulations, args.max_plies, args.workers, args.replay_size) < 1 or min(args.seed, args.opening_plies) < 0:
        parser.error('positive counts and nonnegative seed/opening-plies required')
    if args.gate_games < 2 or args.gate_games % 2 or not 0 <= args.value_loss_weight <= 1:
        parser.error('gate-games must be positive/even, loss weight finite in [0,1]')
    if args.regression_games < 2 or args.regression_games % 2:
        parser.error('regression-games must be positive/even')
    if not 0 <= args.root_fraction <= 1 or not 0 <= args.promote_score <= 1 or not 0 <= args.weight_decay < 1:
        parser.error('root-fraction/promote-score in [0,1], weight-decay in [0,1)')
    if args.output.exists():
        parser.error('output already exists; resume into a new directory')
    started = time.monotonic()
    gate_fixture = args.fixture[0]
    torch.set_num_threads(1)
    torch.manual_seed(args.seed)
    rng = np.random.default_rng(args.seed)
    champion = load_model(args.checkpoint) if args.checkpoint else PolicyValue(local_policy=True).eval()
    learner = copy.deepcopy(champion)
    optimizer = torch.optim.Adam(learner.parameters(), lr=0.001)
    replay = []
    seen_endgames = set()
    completed = 0
    next_fixture_seed = args.seed
    next_match_seed = args.seed + 100000
    if args.resume:
        state = torch.load(args.resume, map_location='cpu', weights_only=True)
        if state['format'] != FORMAT or state['rulesHash'] != rules_hash():
            parser.error('resume encoding/rules differ')
        champion = PolicyValue(local_policy=state.get('championLocalPolicy', False)).eval()
        learner = PolicyValue(local_policy=state.get('learnerLocalPolicy', False)).eval()
        champion.load_state_dict(state['champion'])
        learner.load_state_dict(state['learner'])
        optimizer = torch.optim.Adam(learner.parameters(), lr=0.001)
        optimizer.load_state_dict(state['optimizer'])
        replay = state['replay']
        seen_endgames = set(state.get('seenEndgames', []))
        completed = state['roundsCompleted']
        next_fixture_seed = state.get('nextFixtureSeed', args.seed)
        next_match_seed = state['nextMatchSeed']
        rng.bit_generator.state = state['rng']
        torch.set_rng_state(state['torchRng'])
    if args.local_policy and learner.local_policy is None:
        learner.enable_local_policy()
        # Append only new parameters, retaining all previous Adam moments and step counts.
        optimizer.param_groups[0]['params'].extend(learner.local_policy.parameters())
    for group in optimizer.param_groups:
        group['weight_decay'] = args.weight_decay  # L2, as in AlphaZero; also overrides resumed value.
    if not all(torch.isfinite(p).all() for model in (champion, learner) for p in model.parameters()):
        parser.error('nonfinite checkpoint parameters')
    args.output.mkdir(parents=True)
    manifest = {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()}
    manifest.update(format=FORMAT, rulesHash=rules_hash(), sourceHash=snapshot_sources(args.output),
                    engineHash=hashlib.sha256((ROOT / '.dart_tool/alphazero_engine').read_bytes()).hexdigest(),
                    torchVersion=torch.__version__, status='running', roundsCompleted=completed,
                    promotion=f'gate score rate >= {args.promote_score} (sign test reported, not required); experiment only')
    manifest_path = args.output / 'manifest.json'
    manifest_path.write_text(json.dumps(manifest, indent=2))
    save_model(champion, args.output / 'champion.pt')

    def save_state():
        path = args.output / 'state.tmp'
        torch.save({'format': FORMAT, 'rulesHash': rules_hash(), 'champion': champion.state_dict(),
                    'learner': learner.state_dict(), 'optimizer': optimizer.state_dict(), 'replay': replay,
                    'championLocalPolicy': champion.local_policy is not None,
                    'learnerLocalPolicy': learner.local_policy is not None,
                    'rng': rng.bit_generator.state, 'torchRng': torch.get_rng_state(),
                    'roundsCompleted': completed, 'nextMatchSeed': next_match_seed,
                    'nextFixtureSeed': next_fixture_seed, 'seenEndgames': sorted(seen_endgames)}, path)
        path.replace(args.output / 'state.pt')

    def frozen(model):
        return copy.deepcopy(model.state_dict()), model.local_policy is not None

    save_state()
    runner = Runner(args.workers)
    try:
        for _ in range(args.rounds):
            if args.stop_after_hours is not None and time.monotonic() - started > args.stop_after_hours * 3600:
                print(json.dumps({'stopped': 'time limit', 'roundsCompleted': completed}), flush=True)
                break
            index = completed
            output = args.output / f'round-{index:04d}'
            output.mkdir()
            save_model(champion, output / 'baseline.pt')
            weights, local = frozen(champion)
            tasks = []
            for game in range(args.games):
                fixture = args.fixture[game % len(args.fixture)]
                tasks.append({'weights': weights, 'local': local, 'simulations': args.simulations,
                              'maxPlies': args.max_plies, 'rngSeed': [args.seed, next_fixture_seed],
                              'fixture': fixture, 'turn': (index * args.games + game) % 2,
                              'fixtureSeed': 2 * next_fixture_seed, 'cappedAsDraw': args.capped_as_draw})
                next_fixture_seed += 1
            clock = time.monotonic()
            outcomes = {}
            with (output / 'selfplay.jsonl').open('w') as positions, (output / 'games.jsonl').open('w') as traces:
                for game, (examples, result) in enumerate(runner.map(_selfplay_task, tasks)):
                    result['game'] = game + 1
                    traces.write(json.dumps(result) + '\n')
                    for example in examples:
                        example['game'] = game + 1
                        positions.write(json.dumps(example) + '\n')
                        if result['fixture'].startswith('endgame'):
                            seen_endgames.add(hashlib.sha256(encode(example['observation']).numpy().tobytes()).hexdigest())
                    replay.extend(examples)
                    replay = replay[-args.replay_size:]
                    outcomes[result['outcome']] = outcomes.get(result['outcome'], 0) + 1
                    print(json.dumps({'round': index, 'selfplayGame': game + 1, 'fixture': result['fixture'],
                                      'outcome': result['outcome'], 'plies': result['plies']}), flush=True)
            selfplay_seconds = time.monotonic() - clock
            if not replay:
                raise RuntimeError('No labelled self-play positions: increase cap/search or use --capped-as-draw')
            batch = [replay[i] for i in rng.permutation(len(replay))[:64]]
            before = diagnostics(learner, batch)
            clock = time.monotonic()
            for _ in range(args.updates):
                training = replay_batch(replay, rng, args.root_fraction)
                train_batch(learner, optimizer, training, args.value_loss_weight)
            train_seconds = time.monotonic() - clock
            if not all(torch.isfinite(p).all() for p in learner.parameters()):
                raise RuntimeError('Nonfinite learner: champion retained')
            save_model(learner, output / 'candidate.pt')

            def matches(fixture, count, opening_plies, path):
                tasks = [{'candidate': frozen(learner), 'baseline': frozen(champion),
                          'candidateWhite': game % 2 == 0, 'seed': next_match_seed + game // 2,
                          'simulations': args.gate_simulations, 'maxPlies': args.max_plies,
                          'openingPlies': opening_plies, 'fixture': fixture} for game in range(count)]
                games = []
                with path.open('w') as traces:
                    for game, result in enumerate(runner.map(_match_task, tasks)):
                        if fixture.startswith('endgame') and hashlib.sha256(encode(result['start']).numpy().tobytes()).hexdigest() in seen_endgames:
                            raise RuntimeError('Held-out endgame overlaps replay; gate invalid, champion retained')
                        games.append(result)
                        traces.write(json.dumps(result) + '\n')
                        traces.flush()
                        print(json.dumps({'round': index, 'match': path.stem, 'game': game + 1, 'outcome': result['outcome']}), flush=True)
                return games

            clock = time.monotonic()
            games = matches(gate_fixture, args.gate_games, args.opening_plies, output / 'gate-games.jsonl')
            decision = promotion_decision(games, args.promote_score)
            next_match_seed += args.gate_games // 2
            regression = None
            if decision['promote'] and args.regression_fixture:
                regression = regression_decision(matches(args.regression_fixture, args.regression_games, 0,
                                                         output / 'regression-games.jsonl'))
                decision['promote'] = regression['pass']
                next_match_seed += args.regression_games // 2
            report = {'round': index, 'replayPositions': len(replay), 'updates': args.updates,
                      'selfplayOutcomes': outcomes,
                      'seconds': {'selfplay': selfplay_seconds, 'train': train_seconds, 'gate': time.monotonic() - clock},
                      'fitBefore': before, 'fitAfter': diagnostics(learner, batch),
                      'outcomes': {name: sum(game['outcome'] == name for game in games)
                                   for name in ('candidate', 'baseline', 'draw', 'unfinished')},
                      'gate': decision, 'regression': regression, 'matchSeed': games[0]['seed']}
            (output / 'report.json').write_text(json.dumps(report, indent=2))
            if decision['promote']:
                champion = copy.deepcopy(learner)
                save_model(champion, args.output / 'champion.pt')
            completed += 1
            save_state()
            manifest['roundsCompleted'] = completed
            manifest_path.write_text(json.dumps(manifest, indent=2))
            print(json.dumps(report), flush=True)
        manifest['status'] = 'completed'
    finally:
        runner.close()
        if manifest['status'] == 'running':
            manifest['status'] = 'failed-or-interrupted'
        manifest_path.write_text(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
