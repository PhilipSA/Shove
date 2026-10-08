"""Frozen champion JSON-lines service; engine retains exact game history."""
import argparse
import json
from pathlib import Path
import sys

import numpy as np
import torch

from train import Engine, ROOT, choose_move, load_model, search


def respond(engine, model, request, rng, simulations):
    op = request.get('op')
    if op == 'choose':
        observation = engine.ask('observe')
        stats = {}
        policy = search(engine, model, observation, simulations, rng, noise=False, stats=stats)
        index = choose_move(policy, rng)
        # Choosing does not advance the game: push the selected move after accepting it.
        return {'index': index, 'move': observation['moves'][index],
                'policy': policy.tolist(), 'search': stats}
    if op == 'push':
        observation = engine.ask('observe')
        move = request.get('move')
        if move not in observation['moves']:
            raise ValueError('push requires a legal [from, to, actor] move; actor=64 when absent')
        return engine.ask('push', index=observation['moves'].index(move))
    if op == 'reset':
        return engine.ask('reset', fixture=request.get('fixture', 'initial'),
                          turn=request.get('turn', 0), seed=request.get('seed', 0))
    if op in ('observe', 'pop'):
        return engine.ask(op)
    raise ValueError('Supported ops: reset, observe, push, pop, choose')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--checkpoint', type=Path, default=ROOT / 'champion.pt')
    parser.add_argument('--engine', type=Path, default=ROOT / '.dart_tool/alphazero_engine')
    parser.add_argument('--simulations', type=int, default=256)
    parser.add_argument('--seed', type=int, default=1)
    args = parser.parse_args()
    if args.simulations < 1 or args.seed < 0:
        parser.error('simulations must be positive and seed nonnegative')
    torch.set_num_threads(1)
    model = load_model(args.checkpoint)
    rng = np.random.default_rng(args.seed)
    engine = Engine(args.engine.resolve())
    try:
        for line in sys.stdin:
            try:
                request = json.loads(line)
                if not isinstance(request, dict):
                    raise ValueError('Request must be a JSON object')
                result = respond(engine, model, request, rng, args.simulations)
            except (ValueError, TypeError, RuntimeError) as error:
                result = {'error': str(error)}
            print(json.dumps(result), flush=True)
    finally:
        engine.close()


if __name__ == '__main__':
    main()
