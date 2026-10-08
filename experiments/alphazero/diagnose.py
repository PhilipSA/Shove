"""Frozen held-out decision diagnostics; no training, promotion or optimal-value claims."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

import numpy as np
import torch

from train import Engine, ROOT, choose_move, encode, load_model, rules_hash, search, snapshot_sources


class SplitHeads:
    def __init__(self, policy, value):
        self.policy, self.value = policy, value

    def predict(self, observation):
        return self.policy.predict(observation)[0], self.value.predict(observation)[1]


def immediate_tactics(engine, observation):
    """Exact one-move wins and losing moves/replies; not a general solver."""
    wins, unsafe = [], []
    side = observation['turn']
    for index in range(len(observation['moves'])):
        after = engine.ask('push', index=index)
        try:
            if after['terminal']:
                if after['winner'] == side:
                    wins.append(index)
                elif after['winner'] is not None:
                    unsafe.append(index)
            else:
                for reply in range(len(after['moves'])):
                    result = engine.ask('push', index=reply)
                    engine.ask('pop')
                    if result['terminal'] and result['winner'] == 1 - side:
                        unsafe.append(index)
                        break
        finally:
            engine.ask('pop')
    if engine.ask('observe') != observation:
        raise RuntimeError('Tactical oracle did not restore board/history')
    return {'wins': wins, 'unsafe': unsafe,
            'safe': [i for i in range(len(observation['moves'])) if i not in unsafe]}


def decision_metrics(policy, target, choice, oracle):
    target = np.asarray(target)
    policy = np.asarray(policy)
    positive = target > 0
    kl = None if np.any(policy[positive] == 0) else float(np.sum(target[positive] * (np.log(target[positive]) - np.log(policy[positive]))))
    middle = (target + policy) / 2
    js = 0.0
    for distribution in (target, policy):
        mask = distribution > 0
        js += float(np.sum(distribution[mask] * (np.log(distribution[mask]) - np.log(middle[mask])))) / 2
    return {'teacherTopAgreement': bool(target[choice] == target.max()), 'teacherKl': kl, 'teacherJs': js,
            'teacherVisitShare': float(target[choice]),
            'missedImmediateWin': bool(oracle['wins'] and choice not in oracle['wins']),
            'avoidableImmediateLoss': bool(oracle['safe'] and choice in oracle['unsafe'])}


def summarize(records):
    result = {'positions': len(records), 'variants': {}}
    for name in records[0]['decisions']:
        decisions = [r['decisions'][name] for r in records]
        result['variants'][name] = {key: sum(d[key] for d in decisions) / len(decisions)
                                   for key in ('teacherTopAgreement', 'teacherJs', 'teacherVisitShare')}
        finite_kl = [d['teacherKl'] for d in decisions if d['teacherKl'] is not None]
        result['variants'][name].update(teacherKlWhenFullSupport=sum(finite_kl) / len(finite_kl) if finite_kl else None,
                                      fullSupportPositions=len(finite_kl))
        result['variants'][name].update(
            missedImmediateWins=sum(d['missedImmediateWin'] for d in decisions),
            avoidableImmediateLosses=sum(d['avoidableImmediateLoss'] for d in decisions))
    completed = [r for r in records if r['continuation']['terminal']]
    result['teacherContinuationsCompleted'] = len(completed)
    result['teacherContinuationsUnfinished'] = len(records) - len(completed)
    result['rootsWithImmediateWins'] = sum(bool(r['oracle']['wins']) for r in records)
    result['rootsWithAvoidableLosses'] = sum(bool(r['oracle']['unsafe'] and r['oracle']['safe']) for r in records)
    result['values'] = {}
    for name in records[0]['values']:
        result['values'][name] = {
            'mseAgainstTeacherContinuation': sum((r['values'][name] - r['continuation']['label']) ** 2 for r in completed) / len(completed) if completed else None,
            'meanAbsValueOnUnfinished': np.mean([abs(r['values'][name]) for r in records if not r['continuation']['terminal']]).item() if len(completed) < len(records) else None}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--teacher', type=Path, required=True)
    parser.add_argument('--student', type=Path, required=True)
    parser.add_argument('--training-state', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--positions', type=int, default=60)
    parser.add_argument('--seed', type=int, default=300401)
    parser.add_argument('--teacher-simulations', type=int, default=256)
    parser.add_argument('--student-simulations', type=int, default=32)
    parser.add_argument('--max-plies', type=int, default=100)
    args = parser.parse_args()
    if min(args.positions, args.teacher_simulations, args.student_simulations, args.max_plies) < 1 or args.seed < 0:
        parser.error('positive counts and nonnegative seed required')
    if args.output.exists():
        parser.error('output already exists')
    torch.set_num_threads(1)
    state = torch.load(args.training_state, map_location='cpu', weights_only=True)
    if state['rulesHash'] != rules_hash():
        parser.error('training registry uses different rules')
    seen = set(state['seenEndgames'])
    args.output.mkdir(parents=True)
    manifest = {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()}
    manifest.update(sourceHash=snapshot_sources(args.output), rulesHash=rules_hash(), status='running', hashes={})
    for name in ('teacher', 'student'):
        path = args.output / f'{name}.pt'
        shutil.copyfile(getattr(args, name), path)
        manifest['hashes'][name] = hashlib.sha256(path.read_bytes()).hexdigest()
    manifest['hashes']['trainingState'] = hashlib.sha256(args.training_state.read_bytes()).hexdigest()
    manifest['engineHash'] = hashlib.sha256((ROOT / '.dart_tool/alphazero_engine').read_bytes()).hexdigest()
    manifest_path = args.output / 'manifest.json'
    manifest_path.write_text(json.dumps(manifest, indent=2))
    teacher = load_model(args.output / 'teacher.pt')
    student = load_model(args.output / 'student.pt')
    variants = {'champion32': teacher, 'learner32': student,
                'learnerPolicy_championValue32': SplitHeads(student, teacher),
                'championPolicy_learnerValue32': SplitHeads(teacher, student)}
    records = []
    engine = Engine(ROOT / '.dart_tool/alphazero_engine')
    try:
        with (args.output / 'positions.jsonl').open('w') as output:
            for i in range(args.positions):
                seed = 2 * (args.seed + i) + 1
                side = i % 2
                observation = engine.ask('reset', fixture='endgame-tactics', seed=seed, turn=side)
                signature = hashlib.sha256(encode(observation).numpy().tobytes()).hexdigest()
                if signature in seen:
                    raise RuntimeError('Held-out diagnostic root overlaps training')
                oracle = immediate_tactics(engine, observation)
                stats = {}
                target = search(engine, teacher, observation, args.teacher_simulations,
                                np.random.default_rng(seed), stats=stats)
                teacher_choice = choose_move(target, np.random.default_rng(seed))
                record = {'seed': seed, 'startingTurn': side, 'family': ['hook', 'throw', 'charge'][seed % 3],
                          'observation': observation, 'oracle': oracle, 'teacherPolicy': target.tolist(),
                          'teacherStats': stats, 'decisions': {},
                          'values': {'championRaw': teacher.predict(observation)[1],
                                     'learnerRaw': student.predict(observation)[1],
                                     'teacherSearch': stats['rootValue']}}
                record['decisions']['teacher256'] = dict(decision_metrics(target, target, teacher_choice, oracle), choice=teacher_choice)
                for name, model in variants.items():
                    policy_stats = {}
                    policy = search(engine, model, observation, args.student_simulations,
                                    np.random.default_rng(seed), stats=policy_stats)
                    choice = choose_move(policy, np.random.default_rng(seed))
                    record['decisions'][name] = dict(decision_metrics(policy, target, choice, oracle),
                                                     choice=choice, search=policy_stats)
                for name, model in [('championPrior', teacher), ('learnerPrior', student)]:
                    policy = model.predict(observation)[0]
                    choice = choose_move(policy, np.random.default_rng(seed))
                    record['decisions'][name] = dict(decision_metrics(policy, target, choice, oracle), choice=choice)
                if engine.ask('observe') != observation:
                    raise RuntimeError('Diagnostic search changed root')
                current = observation
                moves = []
                rng = np.random.default_rng(seed)
                policy = target
                for ply in range(args.max_plies):
                    if ply:
                        policy = search(engine, teacher, current, args.teacher_simulations, rng)
                    index = teacher_choice if ply == 0 else choose_move(policy, rng)
                    moves.append(current['moves'][index])
                    current = engine.ask('push', index=index)
                    if current['terminal']:
                        break
                label = None if not current['terminal'] else 0 if current['winner'] is None else 1 if current['winner'] == side else -1
                record['continuation'] = {'terminal': current['terminal'], 'label': label,
                                          'moves': moves, 'final': current}
                records.append(record)
                output.write(json.dumps(record) + '\n')
                output.flush()
                print(json.dumps({'position': i + 1, 'family': record['family'], 'terminal': current['terminal']}), flush=True)
        report = {'all': summarize(records), 'families': {family: summarize([r for r in records if r['family'] == family])
                  for family in ('hook', 'throw', 'charge') if any(r['family'] == family for r in records)},
                  'caveat': 'Teacher agreement/Q and teacher-policy outcomes are proxies, not optimal-play truth; immediate tactics are exact.'}
        (args.output / 'results.json').write_text(json.dumps(report, indent=2))
        print(json.dumps(report['all']), flush=True)
        manifest['status'] = 'completed'
    finally:
        engine.close()
        if manifest['status'] == 'running':
            manifest['status'] = 'failed-or-interrupted'
        manifest_path.write_text(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
