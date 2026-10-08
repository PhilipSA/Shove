"""Replay archived games with the real rules and verify training-label integrity."""
import argparse
import json
import math
from pathlib import Path

from train import Engine, FORMAT, ROOT, rules_hash


def verify_game(engine, fixture, result, examples):
    if result['plies'] != len(result['moves']):
        raise ValueError('Game length differs from its trace')
    completed = result['outcome'] != 'unfinished'
    if not completed and (result['winner'] is not None or result.get('cappedLabel') not in (None, 0)):
        raise ValueError('An unfinished game cannot claim a winner or nonzero cap label')
    # Capped games carry targets only when explicitly labelled 0, never a winner.
    labelled = completed or result.get('cappedLabel') == 0
    if len(examples) != (result['plies'] if labelled else 0):
        raise ValueError('Missing positions or fabricated labels for an unfinished game')
    observation = engine.ask('reset', fixture=fixture, turn=result['startingTurn'], seed=result.get('fixtureSeed', 0))
    for ply, move in enumerate(result['moves']):
        if labelled:
            example = examples[ply]
            if example['observation'] != observation:
                raise ValueError(f'Saved position differs from replay at ply {ply}')
            policy = example['policy']
            if (len(policy) != len(observation['moves']) or
                    any(not math.isfinite(p) or p < 0 for p in policy) or
                    not math.isclose(sum(policy), 1.0, abs_tol=1e-6)):
                raise ValueError(f'Invalid policy target at ply {ply}')
            label = 0 if result['winner'] is None else (
                1 if observation['turn'] == result['winner'] else -1)
            if example['value'] != label:
                raise ValueError(f'Wrong side-to-move outcome label at ply {ply}')
        observation = engine.ask('push', index=observation['moves'].index(move))
    if observation != result['final'] or observation['terminal'] != completed:
        raise ValueError('Final position or terminal status differs from replay')
    if completed and (observation['winner'] != result['winner'] or
                      observation['reason'] != result['outcome']):
        raise ValueError('Reported result differs from engine adjudication')
    return len(examples)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    args = parser.parse_args()
    manifest = json.loads((args.run / 'manifest.json').read_text())
    if manifest['format'] != FORMAT or manifest['rulesHash'] != rules_hash():
        parser.error('Run uses different encoding or rules')
    batches = [('validation.jsonl', 'validation-games.jsonl')]
    batches += [(f'selfplay-{i}.jsonl', f'games-{i}.jsonl')
                for i in range(manifest['iterationsCompleted'])]
    engine = Engine(ROOT / '.dart_tool/alphazero_engine')
    games = positions = 0
    try:
        for samples_path, games_path in batches:
            grouped = {}
            for line in (args.run / samples_path).read_text().splitlines():
                example = json.loads(line)
                grouped.setdefault(example['game'], []).append(example)
            for line in (args.run / games_path).read_text().splitlines():
                result = json.loads(line)
                positions += verify_game(engine, manifest['fixture'], result,
                                         grouped.pop(result['game'], []))
                games += 1
            if grouped:
                raise ValueError('Training positions have no corresponding game trace')
    finally:
        engine.close()
    print(f'Verified {games} exact game replays and {positions} policy/value targets.')


if __name__ == '__main__':
    main()
