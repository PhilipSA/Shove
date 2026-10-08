"""Small AlphaZero-style experiment: real Dart rules, PUCT, policy/value learning."""
import argparse
from dataclasses import dataclass, field
import hashlib
import json
import math
from pathlib import Path
import subprocess
import tarfile

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F

ROOT = Path(__file__).resolve().parents[2]
FORMAT = 'shove-az-v2-relative'


class Engine:
    def __init__(self, executable):
        self.process = subprocess.Popen([str(executable)], stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, text=True, bufsize=1)

    def ask(self, op, **args):
        self.process.stdin.write(json.dumps({'op': op, **args}) + '\n')
        self.process.stdin.flush()
        line = self.process.stdout.readline()
        if not line:
            raise RuntimeError(f'Dart engine exited: {self.process.poll()}')
        observation = json.loads(line)
        if 'error' in observation:
            raise ValueError(observation['error'])
        return observation

    def close(self):
        self.process.stdin.close()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
        self.process.stdout.close()


def encode(observation):
    board = torch.tensor(observation['board'], dtype=torch.long)
    # Own pieces always occupy channels 0–5 and advance toward row zero.
    # No absolute-color channel: otherwise a one-sided dataset teaches "White wins".
    code = board - 1
    relative = torch.where(board > 0, 1 + code % 6 +
                           ((code // 6) % 2 != observation['turn']).long() * 6 +
                           (code // 12) * 12, 0).reshape(8, 8)
    if observation['turn'] == 1:
        relative = relative.flip(0)
    # ponytail: board-only value; engine retains exact history, add history inputs if needed.
    return F.one_hot(relative.flatten(), num_classes=25)[:, 1:].T.reshape(1, 24, 8, 8).float()


def encode_moves(observation):
    moves = torch.tensor(observation['moves'], dtype=torch.long)
    if observation['turn'] == 1:
        moves = torch.where(moves == 64, 64, (7 - moves // 8) * 8 + moves % 8)
    return moves


class PolicyValue(nn.Module):
    def __init__(self, local_policy=False):
        super().__init__()
        self.board = nn.Sequential(nn.Conv2d(24, 16, 3, padding=1), nn.ReLU(),
                                   nn.Conv2d(16, 16, 3, padding=1), nn.ReLU(),
                                   nn.Flatten(), nn.Linear(1024, 64), nn.ReLU())
        self.value = nn.Linear(64, 1)
        self.policy = nn.Linear(64, 32)
        self.squares = nn.ModuleList([nn.Embedding(65, 8) for _ in range(3)])
        self.action = nn.Sequential(nn.Linear(24, 32), nn.Tanh())
        self.local_policy = None
        if local_policy:
            self.enable_local_policy()

    def enable_local_policy(self):
        if self.local_policy is not None:
            raise ValueError('Local policy is already enabled')
        self.local_policy = nn.Sequential(nn.Linear(143, 64), nn.ReLU(), nn.Linear(64, 1))
        # Residual starts at zero: old predictions survive the architecture upgrade.
        nn.init.zeros_(self.local_policy[-1].weight)
        nn.init.zeros_(self.local_policy[-1].bias)

    def forward(self, observation):
        if self.local_policy is None:
            hidden = self.board(encode(observation))
        else:
            features = self.board[:4](encode(observation))
            hidden = self.board[4:](features)
        moves = encode_moves(observation)
        action = torch.cat([embedding(moves[:, i])
                            for i, embedding in enumerate(self.squares)], dim=1)
        logits = (self.action(action) @ self.policy(hidden).T).squeeze(1) / math.sqrt(32)
        if self.local_policy is not None:
            grid = features.flatten(2).squeeze(0).T
            grid = torch.cat([grid, grid.new_zeros(1, 16)])  # Sentinel 64 means no actor.
            squares = torch.where(moves == 64, 0, moves)
            geometry = torch.stack([squares[:, i] // 8 for i in range(3)] +
                                   [squares[:, i] % 8 for i in range(3)], dim=1).float() / 7
            local = torch.cat([grid[moves[:, i]] for i in range(3)] +
                              [action, hidden.expand(len(moves), -1), geometry,
                               (moves[:, 2] != 64).float().unsqueeze(1)], dim=1)
            logits = logits + self.local_policy(local).squeeze(1)
        return logits, self.value(hidden).tanh().squeeze()

    @torch.no_grad()
    def predict(self, observation):
        logits, value = self(observation)
        return logits.softmax(0).numpy(), value.item()


@dataclass
class Node:
    prior: float = 1.0
    visits: int = 0
    total: float = 0.0
    observation: dict | None = None
    children: list = field(default_factory=list)

    @property
    def mean(self):
        return self.total / self.visits if self.visits else 0.0


def expand(node, model, value_scale=1.0):
    if node.observation['terminal']:
        return float(node.observation['value'])
    priors, value = model.predict(node.observation)
    node.children = [Node(prior=float(prior)) for prior in priors]
    return value * value_scale


def search(engine, model, observation, simulations, rng, noise=False, *, cycle_guard=True, value_scale=1.0, stats=None):
    if observation['terminal'] or simulations < 1:
        raise ValueError('Search needs a non-terminal position and positive simulations')
    root = Node(observation=observation)
    expand(root, model, value_scale)
    if noise:
        # AlphaZero scales alpha inversely with typical branching (0.3 at ~35 chess moves).
        exploration = rng.dirichlet(np.full(len(root.children), min(1.0, 10 / len(root.children))))
        for child, random_prior in zip(root.children, exploration):
            child.prior = 0.75 * child.prior + 0.25 * float(random_prior)
    metrics = {'simulations': simulations, 'cycles': 0, 'maxDepth': 0}
    for _ in range(simulations):
        node = root
        path = [root]
        seen = {(tuple(root.observation['board']), root.observation['turn'])}
        repeated = False
        pushed = 0
        try:
            while node.children:
                # Child values are from the opponent's perspective.
                scores = [-child.mean + 1.5 * child.prior * math.sqrt(node.visits + 1)
                          / (child.visits + 1) for child in node.children]
                index = int(np.argmax(scores))
                observation = engine.ask('push', index=index)
                pushed += 1
                node = node.children[index]
                if node.observation is None:
                    node.observation = observation
                path.append(node)
                identity = (tuple(observation['board']), observation['turn'])
                if cycle_guard and not observation['terminal'] and identity in seen:
                    repeated = True
                    metrics['cycles'] += 1
                    break
                seen.add(identity)
            metrics['maxDepth'] = max(metrics['maxDepth'], pushed)
            # ponytail: simulated board cycles get neutral value, not a fabricated game draw.
            # The engine still owns actual history-dependent termination and winning states.
            value = 0.0 if repeated else expand(node, model, value_scale)
            for ancestor in reversed(path):
                ancestor.visits += 1
                ancestor.total += value
                value = -value
        finally:
            for _ in range(pushed):
                engine.ask('pop')
    visits = np.array([child.visits for child in root.children], dtype=float)
    # A proven immediate win beats an optimistic nonterminal estimate, regardless of prior.
    # No extra probes/budget: only terminal children actually visited by this search qualify.
    wins = np.array([child.observation is not None and child.observation['terminal']
                     and child.observation['value'] == -1 for child in root.children])
    policy_visits = np.where(wins, visits, 0) if wins.any() else visits
    if stats is not None:
        stats.update(metrics, rootValue=1.0 if wins.any() else root.mean,
                     actionValues=[-child.mean if child.visits else None for child in root.children],
                     actionVisits=[child.visits for child in root.children],
                     policyVisits=policy_visits.tolist(),
                     policySource='provenImmediateWin' if wins.any() else 'visits')
    return policy_visits / policy_visits.sum()


def choose_move(policy, rng):
    # Equal visits must not systematically favor the first piece in board enumeration.
    return int(rng.choice(np.flatnonzero(policy == policy.max())))


def self_play(engine, model, simulations, max_plies, rng, fixture='initial', starting_turn=0, cycle_guard=True, value_scale=1.0, fixture_seed=0, capped_as_draw=False):
    observation = engine.ask('reset', fixture=fixture, turn=starting_turn, seed=fixture_seed)
    examples = []
    played = []
    search_stats = {'cycles': 0, 'totalMaxDepth': 0, 'maxDepth': 0}
    for ply in range(max_plies):
        stats = {}
        policy = search(engine, model, observation, simulations, rng, noise=True,
                        cycle_guard=cycle_guard, value_scale=value_scale, stats=stats)
        search_stats['cycles'] += stats['cycles']
        search_stats['totalMaxDepth'] += stats['maxDepth']
        search_stats['maxDepth'] = max(search_stats['maxDepth'], stats['maxDepth'])
        examples.append({'observation': observation, 'policy': policy.tolist()})
        index = int(rng.choice(len(policy), p=policy)) if ply < 20 else choose_move(policy, rng)
        played.append(observation['moves'][index])
        observation = engine.ask('push', index=index)
        if observation['terminal']:
            winner = observation['winner']
            for example in examples:
                example['value'] = 0.0 if winner is None else (
                    1.0 if example['observation']['turn'] == winner else -1.0)
            return examples, {'outcome': observation['reason'], 'winner': winner,
                              'startingTurn': starting_turn, 'fixtureSeed': fixture_seed,
                              'plies': len(played), 'moves': played, 'final': observation, 'search': search_stats}
    # A ply cap is not an engine draw: the outcome stays 'unfinished'. Optionally train it
    # with a 0 value target (common practice), so long positions are not excluded.
    for example in examples:
        example['value'] = 0.0
    return examples if capped_as_draw else [], {
        'outcome': 'unfinished', 'winner': None, 'startingTurn': starting_turn, 'fixtureSeed': fixture_seed,
        'plies': len(played), 'moves': played, 'final': observation, 'search': search_stats,
        'cappedLabel': 0.0 if capped_as_draw else None}


@torch.no_grad()
def measure(model, examples):
    if not examples:
        return None
    policy_loss = value_error = correct = decisive = white_error = black_error = 0.0
    for example in examples:
        logits, value = model(example['observation'])
        target = torch.tensor(example['policy'], dtype=torch.float32)
        policy_loss += -(target * logits.log_softmax(0)).sum().item()
        value_error += (value.item() - example['value']) ** 2
        white_prediction = 1.0 if example['observation']['turn'] == 0 else -1.0
        white_error += (white_prediction - example['value']) ** 2
        black_error += (-white_prediction - example['value']) ** 2
        if example['value'] != 0:
            decisive += 1
            correct += (value.item() > 0) == (example['value'] > 0)
    return {'positions': len(examples), 'policyCrossEntropy': policy_loss / len(examples),
            'valueMse': value_error / len(examples),
            'whiteWinBaselineMse': white_error / len(examples),
            'blackWinBaselineMse': black_error / len(examples),
            'decisiveSignAccuracy': correct / decisive if decisive else None}


def train_batch(model, optimizer, examples, value_loss_weight=1.0):
    if not examples:
        return None
    model.train()
    optimizer.zero_grad()
    total = 0.0
    for example in examples:
        logits, value = model(example['observation'])
        target = torch.tensor(example['policy'], dtype=torch.float32)
        policy_loss = -(target * logits.log_softmax(0)).sum()
        value_loss = (value - example['value']).square()
        loss = (policy_loss + value_loss_weight * value_loss) / len(examples)
        loss.backward()
        total += loss.item()
    nn.utils.clip_grad_norm_(model.parameters(), 5.0)
    optimizer.step()
    model.eval()
    return total


def rules_hash():
    digest = hashlib.sha256()
    for path in sorted((ROOT / 'lib/game_objects').rglob('*.dart')):
        digest.update(path.relative_to(ROOT).as_posix().encode() + b'\0' + path.read_bytes())
    return digest.hexdigest()


def load_model(path):
    checkpoint = torch.load(path, map_location='cpu', weights_only=True)
    if checkpoint['format'] != FORMAT or checkpoint['rulesHash'] != rules_hash():
        raise ValueError('Checkpoint encoding or rules differ from this experiment')
    model = PolicyValue(local_policy=checkpoint.get('localPolicy', False)).eval()
    model.load_state_dict(checkpoint['model'])
    return model


def save_model(model, path):
    temporary = path.with_suffix('.tmp')
    torch.save({'format': FORMAT, 'rulesHash': rules_hash(), 'model': model.state_dict(),
                'localPolicy': model.local_policy is not None}, temporary)
    temporary.replace(path)


def snapshot_sources(output):
    sources = sorted([*(ROOT / 'lib').rglob('*.dart'),
                      *(ROOT / 'experiments/alphazero').glob('*.py'),
                      ROOT / 'experiments/alphazero/engine.dart',
                      ROOT / 'experiments/alphazero/run.sh',
                      ROOT / 'experiments/alphazero/requirements.txt',
                      ROOT / 'pubspec.yaml', ROOT / 'pubspec.lock'])
    digest = hashlib.sha256()
    with tarfile.open(output / 'sources.tar.gz', 'w:gz') as archive:
        for source in sources:
            archive.add(source, arcname=source.relative_to(ROOT))
            digest.update(source.relative_to(ROOT).as_posix().encode() + b'\0' + source.read_bytes())
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, default=ROOT / '.dart_tool/alphazero_engine')
    parser.add_argument('--output', type=Path, default=ROOT / '.dart_tool/alphazero-run')
    parser.add_argument('--checkpoint', type=Path)
    parser.add_argument('--games', type=int, default=2)
    parser.add_argument('--iterations', type=int, default=1)
    parser.add_argument('--updates', type=int, default=1, help='Gradient batches per iteration')
    parser.add_argument('--value-loss-weight', type=float, default=1.0,
                        help='Balance shared-encoder policy/value gradients; does not scale inference values')
    parser.add_argument('--validation-games', type=int, default=0,
                        help='Fixed held-out games generated before training, using seed + 10000')
    parser.add_argument('--simulations', type=int, default=16)
    parser.add_argument('--no-cycle-guard', action='store_true', help='Search ablation only')
    parser.add_argument('--value-scale', type=float, default=1.0,
                        help='Calibrate non-terminal network values; terminal results remain exact')
    parser.add_argument('--max-plies', type=int, default=300)
    parser.add_argument('--fixture', choices=['initial', 'race', 'endgame', 'endgame6', 'endgame8', 'endgame-tactics'], default='initial')
    parser.add_argument('--seed', type=int, default=1)
    args = parser.parse_args()
    if min(args.games, args.iterations, args.updates, args.simulations, args.max_plies) < 1 or min(args.seed, args.validation_games) < 0:
        parser.error('counts must be positive; seed and validation-games nonnegative')
    if not 0 <= args.value_scale <= 1:
        parser.error('value-scale must be finite and between 0 and 1')
    if not 0 <= args.value_loss_weight <= 1:
        parser.error('value-loss-weight must be finite and between 0 and 1')
    if args.output.exists():
        parser.error('output already exists; choose a new directory to preserve prior evidence')
    torch.set_num_threads(1)  # Keep the experiment from competing with the other agent's matches.
    torch.manual_seed(args.seed)
    rng = np.random.default_rng(args.seed)
    try:
        model = load_model(args.checkpoint) if args.checkpoint else PolicyValue().eval()
    except ValueError as error:
        parser.error(str(error))
    rules = rules_hash()
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    args.output.mkdir(parents=True)
    source_hash = snapshot_sources(args.output)
    manifest = {key: str(value) if isinstance(value, Path) else value
                for key, value in vars(args).items()}
    manifest.update(format=FORMAT, rulesHash=rules, sourceHash=source_hash,
                    moveSelection='sample first 20 plies, then seeded random max-visit ties',
                    cycleGuard=not args.no_cycle_guard,
                    engineHash=hashlib.sha256(args.engine.read_bytes()).hexdigest(),
                    torchVersion=torch.__version__,
                    gitHead=subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip(),
                    status='running', iterationsCompleted=0)
    manifest_path = args.output / 'manifest.json'
    manifest_path.write_text(json.dumps(manifest, indent=2))
    save_model(model, args.output / 'initial-model.pt')
    replay = []
    engine = Engine(args.engine.resolve())
    try:
        validation = []
        validation_rng = np.random.default_rng(args.seed + 10000)
        with (args.output / 'validation.jsonl').open('w') as positions, (args.output / 'validation-games.jsonl').open('w') as games:
            for game in range(args.validation_games):
                examples, result = self_play(engine, model, args.simulations, args.max_plies, validation_rng, args.fixture, game % 2, cycle_guard=not args.no_cycle_guard, value_scale=args.value_scale,
                                             fixture_seed=2 * (10_000_000 + args.seed + game) + 1)
                result['game'] = game + 1
                games.write(json.dumps(result) + '\n')
                for example in examples:
                    example['game'] = game + 1
                    positions.write(json.dumps(example) + '\n')
                validation.extend(examples)
                print(json.dumps({'validationGame': game + 1, 'outcome': result['outcome'], 'plies': result['plies']}), flush=True)
        if args.validation_games and not validation:
            raise RuntimeError('No completed validation games; retry with a higher ply cap or search budget')
        for iteration in range(args.iterations):
            outcomes = {}
            winners = {'white': 0, 'black': 0, 'draw': 0, 'unfinished': 0}
            total_plies = total_max_depth = total_cycles = 0
            with (args.output / f'selfplay-{iteration}.jsonl').open('w') as file, (args.output / f'games-{iteration}.jsonl').open('w') as games:
                for game in range(args.games):
                    examples, result = self_play(engine, model, args.simulations, args.max_plies, rng, args.fixture, (iteration * args.games + game) % 2, cycle_guard=not args.no_cycle_guard, value_scale=args.value_scale,
                                                 fixture_seed=2 * (args.seed + iteration * args.games + game))
                    result['game'] = iteration * args.games + game + 1
                    total_plies += result['plies']
                    total_max_depth += result['search']['totalMaxDepth']
                    total_cycles += result['search']['cycles']
                    games.write(json.dumps(result) + '\n')
                    outcomes[result['outcome']] = outcomes.get(result['outcome'], 0) + 1
                    winner = ('unfinished' if result['outcome'] == 'unfinished' else
                              'draw' if result['winner'] is None else
                              'white' if result['winner'] == 0 else 'black')
                    winners[winner] += 1
                    for example in examples:
                        example['game'] = result['game']
                        file.write(json.dumps(example) + '\n')
                    replay.extend(examples)
                    # ponytail: small bounded replay; minibatched tensors if training throughput matters.
                    replay = replay[-4096:]
                    print(json.dumps({'iteration': iteration, 'game': game + 1, 'outcome': result['outcome'], 'plies': result['plies']}), flush=True)
            before = measure(model, validation)
            losses = []
            if replay:
                for _ in range(args.updates):
                    batch = [replay[i] for i in rng.permutation(len(replay))[:64]]
                    losses.append(train_batch(model, optimizer, batch, args.value_loss_weight))
            report = {'iteration': iteration, 'outcomes': outcomes, 'winners': winners, 'replayPositions': len(replay),
                      'updates': len(losses), 'valueLossWeight': args.value_loss_weight,
                      'loss': sum(losses) / len(losses) if losses else None,
                      'averageMaxSearchDepth': total_max_depth / total_plies,
                      'searchCycles': total_cycles,
                      'validationBefore': before, 'validationAfter': measure(model, validation)}
            print(json.dumps(report), flush=True)
            (args.output / f'report-{iteration}.json').write_text(json.dumps(report, indent=2))
            save_model(model, args.output / 'model.pt')
            manifest['iterationsCompleted'] = iteration + 1
        manifest['status'] = 'completed'
    finally:
        engine.close()
        if manifest['status'] == 'running':
            manifest['status'] = 'failed-or-interrupted'
        manifest_path.write_text(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
