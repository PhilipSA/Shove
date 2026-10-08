import unittest

import numpy as np
import torch

from diagnose import SplitHeads, decision_metrics, immediate_tactics, summarize
from train import Engine, ROOT, PolicyValue, search


class DiagnosisChecks(unittest.TestCase):
    def test_metrics_and_split_heads(self):
        class Fixed:
            def __init__(self, policy, value):
                self.policy, self.value = np.array(policy), value

            def predict(self, observation):
                return self.policy, self.value

        policy, value = SplitHeads(Fixed([0.8, 0.2], -1), Fixed([0.1, 0.9], 0.7)).predict({})
        np.testing.assert_array_equal(policy, [0.8, 0.2])
        self.assertEqual(value, 0.7)
        target = [0.8, 0.2]
        oracle = {'wins': [0], 'unsafe': [1], 'safe': [0]}
        correct = decision_metrics(target, target, 0, oracle)
        self.assertAlmostEqual(correct['teacherKl'], 0)
        self.assertTrue(correct['teacherTopAgreement'])
        wrong = decision_metrics([0.1, 0.9], target, 1, oracle)
        self.assertTrue(wrong['missedImmediateWin'])
        self.assertTrue(wrong['avoidableImmediateLoss'])
        self.assertGreater(wrong['teacherKl'], 0)
        sparse = decision_metrics([0, 1], [1, 0], 1, oracle)
        self.assertIsNone(sparse['teacherKl'])
        self.assertAlmostEqual(sparse['teacherJs'], np.log(2))
        completed = {'decisions': {'test': correct}, 'oracle': oracle, 'values': {'raw': 1},
                     'continuation': {'terminal': True, 'label': -1}}
        unfinished = dict(completed, continuation={'terminal': False, 'label': None})
        summary = summarize([completed, unfinished])
        self.assertEqual(summary['teacherContinuationsUnfinished'], 1)
        self.assertEqual(summary['values']['raw']['mseAgainstTeacherContinuation'], 4)

    def test_exact_tactics_and_search_telemetry_restore_real_rules(self):
        torch.set_num_threads(1)
        engine = Engine(ROOT / '.dart_tool/alphazero_engine')
        try:
            for side in (0, 1):
                observation = engine.ask('reset', fixture='race', turn=side)
                oracle = immediate_tactics(engine, observation)
                self.assertTrue(oracle['wins'])
                for index in oracle['wins']:
                    after = engine.ask('push', index=index)
                    self.assertTrue(after['terminal'])
                    self.assertEqual(after['winner'], side)
                    engine.ask('pop')
                stats = {}
                policy = search(engine, PolicyValue().eval(), observation, 16,
                                np.random.default_rng(1), stats=stats)
                self.assertEqual(sum(stats['actionVisits']), 16)
                counts = np.array(stats['policyVisits'])
                np.testing.assert_allclose(policy, counts / counts.sum())
                for index in oracle['wins']:
                    if stats['actionVisits'][index]:
                        self.assertEqual(stats['actionValues'][index], 1)
                self.assertEqual(engine.ask('observe'), observation)
        finally:
            engine.close()
