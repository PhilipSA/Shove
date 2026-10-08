"""Fixed-data memorization check: learnability, NOT generalization or strength."""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import torch

from train import FORMAT, PolicyValue, load_model, measure, rules_hash, snapshot_sources, train_batch, save_model


def diagnostics(model, examples):
    metrics = measure(model, examples)
    entropy = -sum(sum(p * math.log(p) for p in ex['policy'] if p > 0)
                   for ex in examples) / len(examples)
    return dict(metrics, targetEntropy=entropy,
                policyKl=metrics['policyCrossEntropy'] - entropy)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data', type=Path, required=True)
    parser.add_argument('--checkpoint', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--positions', type=int, default=32)
    parser.add_argument('--updates', type=int, default=1000)
    parser.add_argument('--value-loss-weight', type=float, default=0.01)
    parser.add_argument('--seed', type=int, default=7)
    args = parser.parse_args()
    if min(args.positions, args.updates) < 1 or args.seed < 0 or not 0 <= args.value_loss_weight <= 1:
        parser.error('positive counts, nonnegative seed, finite loss weight in [0,1] required')
    if args.output.exists():
        parser.error('output already exists')
    examples = [json.loads(line) for line in args.data.read_text().splitlines()]
    if len(examples) < args.positions:
        parser.error('not enough positions')
    torch.set_num_threads(1)
    torch.manual_seed(args.seed)
    indices = np.random.default_rng(args.seed).permutation(len(examples))[:args.positions]
    batch = [examples[i] for i in indices]
    model = load_model(args.checkpoint) if args.checkpoint else PolicyValue().eval()
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    args.output.mkdir(parents=True)
    settings = {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()}
    settings.update(sourceHash=snapshot_sources(args.output), rulesHash=rules_hash(), format=FORMAT,
                    dataHash=hashlib.sha256(args.data.read_bytes()).hexdigest(), indices=indices.tolist(),
                    checkpointHash=hashlib.sha256(args.checkpoint.read_bytes()).hexdigest() if args.checkpoint else None)
    (args.output / 'manifest.json').write_text(json.dumps(settings, indent=2))
    reports = [{'update': 0, **diagnostics(model, batch)}]
    print(json.dumps(reports[-1]), flush=True)
    for update in range(1, args.updates + 1):
        train_batch(model, optimizer, batch, args.value_loss_weight)
        if update % 100 == 0 or update == args.updates:
            reports.append({'update': update, **diagnostics(model, batch)})
            (args.output / 'results.json').write_text(json.dumps(reports, indent=2))
            print(json.dumps(reports[-1]), flush=True)
    save_model(model, args.output / 'model.pt')
    print('Memorization only: this checkpoint must NOT be promoted based on fitting loss.')


if __name__ == '__main__':
    main()
