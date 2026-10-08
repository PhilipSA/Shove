"""Freeze a checkpoint as browser-readable Dart weights and optional parity cases."""
import argparse
import hashlib
import io
import json
from pathlib import Path

import numpy as np
import torch

from train import Engine, FORMAT, ROOT, PolicyValue, rules_hash, search


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('checkpoint', type=Path)
    parser.add_argument('output', type=Path, help='New directory; never overwrites an earlier export')
    parser.add_argument('--reference', action='store_true', help='Small Python inference/search parity set')
    parser.add_argument('--reference-simulations', type=int, default=32)
    # No engine build here: never replace the live trainer's executable.
    args = parser.parse_args()
    if args.reference_simulations < 1:
        parser.error('reference-simulations must be positive')
    if args.output.exists():
        parser.error('output exists; choose a new directory')
    torch.set_num_threads(1)
    raw = args.checkpoint.read_bytes()  # One open captures one atomically published checkpoint.
    checkpoint = torch.load(io.BytesIO(raw), map_location='cpu', weights_only=True)
    if checkpoint['format'] != FORMAT or checkpoint['rulesHash'] != rules_hash():
        parser.error('checkpoint rules/encoding mismatch')
    local = checkpoint.get('localPolicy', False)
    model = PolicyValue(local_policy=local).eval()
    model.load_state_dict(checkpoint['model'])
    if not all(torch.isfinite(p).all() for p in model.parameters()):
        parser.error('nonfinite weights')
    data = {'format': 'shove-az-dart-v1', 'encoding': FORMAT,
            'rulesHash': checkpoint['rulesHash'], 'checkpointSha256': hashlib.sha256(raw).hexdigest(),
            'localPolicy': local, 'tensors': {
                name: {'shape': list(tensor.shape), 'data': tensor.flatten().tolist()}
                for name, tensor in model.state_dict().items()}}
    args.output.mkdir(parents=True)
    (args.output / 'champion.pt').write_bytes(raw)
    (args.output / 'weights.json').write_text(json.dumps(data, separators=(',', ':')))
    if args.reference:
        cases = []
        engine = Engine(ROOT / '.dart_tool/alphazero_engine')
        try:
            # Both orientations; initial, immediate-win, actor and incapacitation positions.
            for fixture in ('initial', 'race', 'endgame8', 'endgame-tactics'):
                for turn in (0, 1):
                    for seed in (12, 19):
                        observation = engine.ask('reset', fixture=fixture, turn=turn, seed=seed)
                        record = {'fixture': fixture, 'turn': turn, 'seed': seed, 'moves': []}
                        for ply in range(5):
                            if observation['terminal']:
                                break
                            with torch.no_grad():
                                logits, value = model(observation)
                            stats = {}
                            policy = search(engine, model, observation, args.reference_simulations, np.random.default_rng(1), stats=stats)
                            assert engine.ask('observe') == observation
                            cases.append({'observation': observation, 'setup': dict(record, moves=list(record['moves'])),
                                          'logits': logits.tolist(), 'value': value.item(),
                                          'policy': logits.softmax(0).tolist(), 'searchPolicy': policy.tolist(), 'search': stats,
                                          'simulations': args.reference_simulations})
                            index = (seed + ply * 7) % len(observation['moves'])
                            record['moves'].append(observation['moves'][index])
                            observation = engine.ask('push', index=index)
            # Cover every input channel even if sparse fixtures don't produce every stun/type.
            for turn in (0, 1):
                observation = {'board': [i % 25 for i in range(64)], 'turn': turn,
                               'moves': [[0, 63, 64], [17, 25, 42], [53, 1, 7]]}
                with torch.no_grad():
                    logits, value = model(observation)
                cases.append({'observation': observation, 'logits': logits.tolist(),
                              'value': value.item(), 'policy': logits.softmax(0).tolist()})
        finally:
            engine.close()
        (args.output / 'reference.json').write_text(json.dumps(cases))
    print(json.dumps({'output': str(args.output), 'checkpointSha256': data['checkpointSha256'],
                      'localPolicy': local, 'parameters': sum(p.numel() for p in model.parameters())}))


if __name__ == '__main__':
    main()
