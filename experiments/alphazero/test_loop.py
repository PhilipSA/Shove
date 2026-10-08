import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np
import torch

from loop import promotion_decision, regression_decision, replay_batch
from train import ROOT, PolicyValue, save_model


def paired(outcomes):
    return [{'seed': index // 2, 'candidateWhite': index % 2 == 0,
             'start': {'position': index // 2}, 'outcome': outcome}
            for index, outcome in enumerate(outcomes)]


class ChampionLoop(unittest.TestCase):
    def test_gate_requires_paired_evidence_and_keeps_unfinished_distinct(self):
        convincing = paired(['candidate'] * 10 + ['candidate', 'baseline'] * 5)
        decision = promotion_decision(convincing)
        self.assertTrue(decision['promote'])
        self.assertEqual(decision['worstCaseOneSidedP'], 1 / 32)
        self.assertEqual(decision['pairWins'], 5)
        self.assertEqual(decision['tiedPairs'], 5)
        self.assertFalse(promotion_decision(paired(['candidate', 'baseline'] * 10))['promote'])
        self.assertFalse(promotion_decision(paired(['baseline'] * 20))['promote'])
        convincing[-1]['outcome'] = 'unfinished'
        decision = promotion_decision(convincing)
        self.assertEqual(decision['unresolvedPairs'], 1)
        self.assertEqual(decision['pairLosses'], 0)
        self.assertEqual(decision['scoreRate'], 15.5 / 20)  # A capped former loss scores half, never a win.
        self.assertTrue(decision['promote'])
        self.assertFalse(decision['significant'])
        self.assertFalse(promotion_decision(paired(['draw'] * 20))['promote'])
        self.assertFalse(promotion_decision(paired(['unfinished'] * 20))['promote'])
        # AlphaGo Zero threshold: 55% exactly promotes; just below does not.
        self.assertTrue(promotion_decision(paired(['candidate'] * 11 + ['baseline'] * 9))['promote'])
        self.assertFalse(promotion_decision(paired(['candidate'] * 10 + ['draw'] + ['baseline'] * 9))['promote'])
        self.assertTrue(promotion_decision(paired(['baseline'] * 20), threshold=0)['promote'])

    def test_root_sampling_is_bounded_distinct_and_seeded(self):
        replay = [{'id': i, 'observation': {'historyLength': 0 if i < 40 else 1}}
                  for i in range(100)]
        first = replay_batch(replay, np.random.default_rng(1), 0.5)
        self.assertEqual(first, replay_batch(replay, np.random.default_rng(1), 0.5))
        self.assertEqual(len(first), 64)
        self.assertEqual(len({ex['id'] for ex in first}), 64)
        self.assertGreaterEqual(sum(ex['id'] < 40 for ex in first), 32)
        self.assertEqual(len(replay_batch(replay[:4], np.random.default_rng(1), 1)), 4)
        plain = replay_batch(replay, np.random.default_rng(1))
        self.assertEqual(plain, [replay[i] for i in np.random.default_rng(1).permutation(100)[:64]])
        self.assertEqual(replay_batch([], np.random.default_rng(1)), [])

    def test_regression_rejects_losses_unfinished_and_errors(self):
        self.assertTrue(regression_decision(paired(['candidate', 'baseline'] * 10))['pass'])
        self.assertFalse(regression_decision(paired(['baseline'] * 20))['pass'])
        self.assertFalse(regression_decision(paired(['candidate', 'unfinished'] * 10))['pass'])
        with self.assertRaises(ValueError):
            regression_decision(paired(['candidate', 'error']))

    def test_errors_and_wrong_pairing_cannot_promote(self):
        for games in ([], paired(['candidate']), paired(['candidate', 'error'])):
            with self.assertRaises(ValueError):
                promotion_decision(games)
        for field, value in [('seed', 100), ('start', {}), ('candidateWhite', True)]:
            games = paired(['candidate'] * 20)
            games[1][field] = value
            with self.assertRaises(ValueError):
                promotion_decision(games)

    def test_real_loop_resume_preserves_optimizer_replay_and_champion(self):
        with tempfile.TemporaryDirectory() as folder:
            first, second = Path(folder) / 'first', Path(folder) / 'second'
            legacy = Path(folder) / 'legacy.pt'
            save_model(PolicyValue().eval(), legacy)
            command = [sys.executable, str(ROOT / 'experiments/alphazero/loop.py'),
                       '--rounds', '1', '--games', '2', '--gate-games', '2', '--updates', '2',
                       '--promote-score', '1', '--weight-decay', '0',
                       '--fixture', 'race', '--opening-plies', '0', '--simulations', '64', '--max-plies', '8']
            subprocess.run([*command, '--checkpoint', str(legacy), '--output', str(first)], check=True, capture_output=True, text=True)
            a = torch.load(first / 'state.pt', weights_only=True)
            subprocess.run([*command, '--resume', str(first / 'state.pt'), '--local-policy', '--output', str(second)],
                           check=True, capture_output=True, text=True)
            b = torch.load(second / 'state.pt', weights_only=True)
            self.assertEqual(a['roundsCompleted'], 1)
            self.assertEqual(b['roundsCompleted'], 2)
            self.assertEqual(b['nextMatchSeed'], a['nextMatchSeed'] + 1)
            self.assertGreater(len(b['replay']), len(a['replay']))
            self.assertTrue(all(torch.equal(a['champion'][k], b['champion'][k]) for k in a['champion']))
            self.assertTrue(any(not torch.equal(a['learner'][k], b['learner'][k]) for k in a['learner']))
            self.assertEqual({int(value['step']) for value in a['optimizer']['state'].values()}, {2})
            self.assertEqual({int(value['step']) for value in b['optimizer']['state'].values()}, {2, 4})
            self.assertTrue(b['learnerLocalPolicy'])
            self.assertFalse(b['championLocalPolicy'])
            third = Path(folder) / 'third'
            subprocess.run([*command, '--resume', str(second / 'state.pt'), '--output', str(third)],
                           check=True, capture_output=True, text=True)
            c = torch.load(third / 'state.pt', weights_only=True)
            self.assertTrue(c['learnerLocalPolicy'])
            self.assertEqual({int(value['step']) for value in c['optimizer']['state'].values()}, {4, 6})
            report = json.loads((second / 'round-0001/report.json').read_text())
            self.assertFalse(report['gate']['promote'])
            self.assertEqual(json.loads((second / 'manifest.json').read_text())['status'], 'completed')
            published = torch.load(second / 'champion.pt', weights_only=True)['model']
            self.assertTrue(all(torch.equal(published[k], b['champion'][k]) for k in published))

    def test_parallel_fresh_mixed_capped_run_is_audited_and_promotes_latest(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'run'
            subprocess.run([sys.executable, str(ROOT / 'experiments/alphazero/loop.py'),
                            '--rounds', '1', '--games', '4', '--gate-games', '4', '--updates', '2',
                            '--workers', '2', '--promote-score', '0', '--capped-as-draw',
                            '--fixture', 'initial', 'endgame', '--opening-plies', '0',
                            '--simulations', '4', '--max-plies', '3', '--output', str(output)],
                           check=True, capture_output=True, text=True)
            state = torch.load(output / 'state.pt', weights_only=True)
            games = [json.loads(line) for line in (output / 'round-0000/games.jsonl').read_text().splitlines()]
            self.assertEqual([g['fixture'] for g in games], ['initial', 'endgame'] * 2)
            self.assertTrue(state['championLocalPolicy'] and state['learnerLocalPolicy'])
            self.assertTrue(all(torch.equal(state['champion'][k], state['learner'][k]) for k in state['learner']))
            capped = [g for g in games if g['outcome'] == 'unfinished']
            self.assertTrue(capped)
            self.assertTrue(all(g['cappedLabel'] == 0 and g['winner'] is None for g in capped))
            labelled = sum(g['plies'] for g in games)
            self.assertEqual(len(state['replay']), labelled)
            self.assertTrue(all(ex['value'] == 0 for ex in state['replay'][:3]))
            report = json.loads((output / 'round-0000/report.json').read_text())
            self.assertTrue(report['gate']['promote'])
            self.assertEqual(sum(report['outcomes'].values()), 4)


if __name__ == '__main__':
    unittest.main()
