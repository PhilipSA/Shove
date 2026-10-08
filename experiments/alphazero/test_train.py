import math
from pathlib import Path
import tempfile
import unittest

import numpy as np
import torch

from train import Engine, PolicyValue, ROOT, choose_move, encode, encode_moves, measure, search, self_play, train_batch, save_model, load_model
from audit import verify_game
from fit import diagnostics


class AlphaZeroSmoke(unittest.TestCase):
    def setUp(self):
        torch.set_num_threads(1)
        torch.manual_seed(1)
        self.model = PolicyValue().eval()
        self.engine = Engine(ROOT / '.dart_tool/alphazero_engine')
        self.rng = np.random.default_rng(1)

    def tearDown(self):
        self.engine.close()

    def test_simulated_cycles_are_neutral_without_fabricating_game_termination(self):
        class TwoStateEngine:
            def __init__(self, terminal=False):
                self.stack = [0]
                self.terminal = terminal

            def observe(self):
                state = self.stack[-1]
                terminal = self.terminal and len(self.stack) > 2
                return {'board': [state] * 64, 'turn': state, 'moves': [[0, 1, 64]],
                        'terminal': terminal, 'value': 1.0 if terminal else 0.0,
                        'historyLength': len(self.stack) - 1}

            def ask(self, op, **args):
                if op == 'push':
                    self.stack.append(1 - self.stack[-1])
                elif op == 'pop':
                    self.stack.pop()
                return self.observe()

        class OptimisticModel:
            def predict(self, observation):
                return np.array([1.0]), 0.9 if observation['turn'] == 0 else -0.9

        for guarded in [True, False]:
            engine = TwoStateEngine()
            original = engine.observe()
            stats = {}
            policy = search(engine, OptimisticModel(), original, 8, self.rng,
                            cycle_guard=guarded, stats=stats)
            np.testing.assert_array_equal(policy, [1.0])
            self.assertEqual(engine.observe(), original)
            self.assertFalse(engine.observe()['terminal'])
            self.assertEqual(stats['simulations'], 8)
            self.assertEqual(stats['cycles'], 7 if guarded else 0)
            self.assertEqual(stats['maxDepth'], 2 if guarded else 8)
            self.assertAlmostEqual(stats['rootValue'], 0.9 / 8 if guarded else 0.9)
        # Engine-adjudicated terminal states take priority over the cycle heuristic.
        engine = TwoStateEngine(terminal=True)
        stats = {}
        search(engine, OptimisticModel(), engine.observe(), 8, self.rng, stats=stats)
        self.assertEqual(stats['cycles'], 0)
        self.assertEqual(stats['maxDepth'], 2)
        self.assertEqual(engine.observe()['historyLength'], 0)
        engine = TwoStateEngine()
        stats = {}
        search(engine, OptimisticModel(), engine.observe(), 8, self.rng,
               cycle_guard=False, value_scale=0, stats=stats)
        self.assertEqual(stats['rootValue'], 0)
        engine = TwoStateEngine(terminal=True)
        search(engine, OptimisticModel(), engine.observe(), 8, self.rng,
               value_scale=0, stats=stats)
        self.assertAlmostEqual(stats['rootValue'], 7 / 8, msg='Terminal results must not be scaled')

    def test_found_immediate_win_beats_more_visited_optimistic_alternative(self):
        class Game:
            def __init__(self):
                self.path = []

            def ask(self, op, **args):
                if op == 'push':
                    self.path.append(args['index'])
                elif op == 'pop':
                    self.path.pop()
                depth = len(self.path)
                won = bool(self.path and self.path[0] == 0)
                return {'board': [depth] * 64, 'turn': depth % 2, 'terminal': won,
                        'value': -1 if won else 0,
                        'moves': [] if won else [[0, 1, 64]] * (1 if depth else 2)}

        class Optimistic:
            def predict(self, observation):
                return (np.array([0.4, 0.6]) if len(observation['moves']) == 2 else np.array([1.0]),
                        1.0 if observation['turn'] == 0 else -1.0)

        engine = Game()
        original = engine.ask('observe')
        stats = {}
        policy = search(engine, Optimistic(), original, 32, self.rng, stats=stats)
        self.assertGreater(stats['actionVisits'][1], stats['actionVisits'][0])
        np.testing.assert_array_equal(policy, [1.0, 0.0])
        self.assertEqual(sum(stats['actionVisits']), 32)
        self.assertEqual(stats['policySource'], 'provenImmediateWin')
        self.assertEqual(engine.ask('observe'), original)

    def test_seeded_ties_are_reproducible_without_first_move_bias(self):
        policy = np.array([0.5, 0.5, 0.0])
        first = np.random.default_rng(42)
        second = np.random.default_rng(42)
        picks = [choose_move(policy, first) for _ in range(32)]
        self.assertEqual(picks, [choose_move(policy, second) for _ in range(32)])
        self.assertEqual(set(picks), {0, 1})
        self.assertEqual(choose_move(np.array([0.0, 1.0, 0.0]), first), 1)

    def test_seeded_endgames_are_varied_reproducible_and_exactly_auditable(self):
        boards = set()
        for seed in range(24):
            original = self.engine.ask('reset', fixture='endgame', seed=seed)
            self.assertEqual(original, self.engine.ask('reset', fixture='endgame', seed=seed))
            self.assertFalse(original['terminal'])
            pieces = [code for code in original['board'] if code]
            self.assertEqual(len(pieces), 4)
            self.assertEqual(pieces.count(1), 1)
            self.assertEqual(pieces.count(7), 1)
            self.assertTrue(original['moves'])
            boards.add(tuple(original['board']))
            self.engine.ask('push', index=0)
            self.assertEqual(self.engine.ask('pop'), original)
        self.assertEqual(len(boards), 24)
        with self.assertRaises(ValueError):
            self.engine.ask('reset', fixture='endgame', seed=-1)
        for turn in [0, 1]:
            examples, result = self_play(self.engine, self.model, 128, 80, self.rng,
                                         fixture='endgame', starting_turn=turn, fixture_seed=18)
            self.assertEqual(result['fixtureSeed'], 18)
            self.assertEqual(verify_game(self.engine, 'endgame', result, examples), len(examples))

    def test_local_policy_preserves_predictions_learns_and_roundtrips(self):
        original = self.engine.ask('reset', fixture='endgame-tactics', seed=1)
        before = self.model.predict(original)
        self.model.enable_local_policy()
        after = self.model.predict(original)
        np.testing.assert_array_equal(before[0], after[0])
        self.assertEqual(before[1], after[1])
        with self.assertRaises(ValueError):
            self.model.enable_local_policy()
        policy = [0.0] * len(original['moves'])
        policy[0] = 1.0
        optimizer = torch.optim.Adam(self.model.parameters(), lr=0.001)
        for _ in range(4):
            train_batch(self.model, optimizer, [{'observation': original, 'policy': policy, 'value': 0}])
        self.assertFalse(np.array_equal(before[0], self.model.predict(original)[0]))
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'model.pt'
            save_model(self.model, path)
            restored = load_model(path)
            self.assertIsNotNone(restored.local_policy)
            np.testing.assert_array_equal(self.model.predict(original)[0], restored.predict(original)[0])
        # Exercise the same color-invariance check with the trained residual enabled.
        self.test_relative_encoding_and_policy_are_color_invariant()

    def test_tactical_positions_have_real_pawn_interactions_in_each_family(self):
        for seed in range(12):
            for turn in [0, 1]:
                original = self.engine.ask('reset', fixture='endgame-tactics', seed=seed, turn=turn)
                self.assertEqual(original, self.engine.ask('reset', fixture='endgame-tactics', seed=seed, turn=turn))
                self.assertEqual(sum(bool(code) for code in original['board']), 6)
                matches = []
                kind = lambda square: (original['board'][square] - 1) % 6
                for index, (start, end, actor) in enumerate(original['moves']):
                    if seed % 3 < 2:
                        qualifies = actor != 64 and kind(start) == 0 and kind(actor) == (5 if seed % 3 == 0 else 1)
                    else:
                        qualifies = actor == 64 and kind(start) == 4 and original['board'][end] != 0 and kind(end) == 0 and max(abs(start // 8 - end // 8), abs(start % 8 - end % 8)) > 1
                    if qualifies:
                        matches.append(index)
                self.assertTrue(matches)
                self.engine.ask('push', index=matches[0])
                self.assertEqual(self.engine.ask('pop'), original)
        examples, result = self_play(self.engine, self.model, 128, 100, self.rng,
                                     fixture='endgame-tactics', fixture_seed=8)
        self.assertEqual(verify_game(self.engine, 'endgame-tactics', result, examples), len(examples))

    def test_broader_endgames_cover_all_types_actors_and_undo(self):
        kinds = set()
        actors = False
        for fixture, count, pawns in [('endgame6', 6, 1), ('endgame8', 8, 2)]:
            for seed in range(64):
                original = self.engine.ask('reset', fixture=fixture, seed=seed)
                self.assertEqual(original, self.engine.ask('reset', fixture=fixture, seed=seed))
                codes = [code for code in original['board'] if code]
                self.assertEqual(len(codes), count)
                self.assertEqual(codes.count(1), pawns)
                self.assertEqual(codes.count(7), pawns)
                kinds.update((code - 1) % 6 for code in codes)
                actors |= any(move[2] != 64 for move in original['moves'])
                priors, _ = self.model.predict(original)
                self.assertEqual(len(priors), len(original['moves']))
                self.assertAlmostEqual(float(priors.sum()), 1, places=5)
                self.engine.ask('push', index=0)
                self.assertEqual(self.engine.ask('pop'), original)
        self.assertEqual(kinds, set(range(6)))
        self.assertTrue(actors)

    def test_policy_kl_diagnostic_removes_irreducible_target_entropy(self):
        original = self.engine.ask('reset', fixture='race')
        policy, value = self.model.predict(original)
        example = {'observation': original, 'policy': policy.tolist(), 'value': value}
        metrics = diagnostics(self.model, [example])
        self.assertAlmostEqual(metrics['policyKl'], 0, places=6)
        self.assertGreater(metrics['targetEntropy'], 0)
        self.assertEqual(metrics['valueMse'], 0)

    def test_encoding_legal_policy_and_engine_undo(self):
        original = self.engine.ask('reset')
        self.assertEqual(tuple(encode(original).shape), (1, 24, 8, 8))
        priors, value = self.model.predict(original)
        self.assertEqual(len(priors), len(original['moves']))
        self.assertAlmostEqual(float(priors.sum()), 1.0, places=5)
        self.assertTrue(-1 <= value <= 1)
        with self.assertRaises(ValueError):
            self.engine.ask('push', index=-1)
        self.assertEqual(self.engine.ask('observe'), original)
        self.engine.ask('push', index=0)
        self.assertEqual(self.engine.ask('pop'), original)

    def test_relative_encoding_and_policy_are_color_invariant(self):
        white = self.engine.ask('reset', fixture='race', turn=0)
        white_priors, white_value = self.model.predict(white)
        # Swap ownership, reflect rows, and swap turn: the same decision in other colors.
        black = dict(white, turn=1, board=[0] * 64)
        for square, code in enumerate(white['board']):
            if code:
                black['board'][(7 - square // 8) * 8 + square % 8] = (
                    code + 6 if (code - 1) % 12 < 6 else code - 6)
        black['moves'] = [[64 if square == 64 else (7 - square // 8) * 8 + square % 8
                           for square in move] for move in white['moves']]
        self.assertTrue(torch.equal(encode(white), encode(black)))
        self.assertTrue(torch.equal(encode_moves(white), encode_moves(black)))
        priors, value = self.model.predict(black)
        np.testing.assert_array_equal(priors, white_priors)
        self.assertEqual(value, white_value)
        self.assertTrue(torch.all(encode_moves(black)[:, 2] == 64))
        with self.assertRaises(ValueError):
            self.engine.ask('reset', turn=2)
        self.assertEqual(self.engine.ask('observe'), white)

    def test_puct_finds_immediate_win_and_restores_board_and_history(self):
        original = self.engine.ask('reset', fixture='race')
        policy = search(self.engine, self.model, original, 64, self.rng)
        self.assertAlmostEqual(float(policy.sum()), 1.0)
        self.assertEqual(self.engine.ask('observe'), original)
        index = int(np.argmax(policy))
        self.assertEqual(original['moves'][index], [9, 1, 64])
        terminal = self.engine.ask('push', index=index)
        self.assertTrue(terminal['terminal'])
        self.assertEqual(terminal['winner'], 0)
        self.assertEqual(terminal['value'], -1, 'terminal value is for side to move')
        black = self.engine.ask('reset', fixture='race', turn=1)
        policy = search(self.engine, self.model, black, 64, self.rng)
        index = int(np.argmax(policy))
        self.assertEqual(black['moves'][index], [54, 62, 64])
        terminal = self.engine.ask('push', index=index)
        self.assertEqual(terminal['winner'], 1)
        self.assertEqual(terminal['value'], -1)
        original = self.engine.ask('reset', fixture='race')
        policy = search(self.engine, self.model, original, 64, self.rng, value_scale=0)
        self.assertEqual(original['moves'][int(np.argmax(policy))], [9, 1, 64])

    def test_completed_selfplay_trains_and_ply_cap_is_not_a_draw(self):
        examples, result = self_play(self.engine, self.model, 64, 8, self.rng, fixture='race')
        self.assertEqual(result['outcome'], 'reachedGoal')
        self.assertEqual(result['plies'], len(examples))
        self.assertGreaterEqual(result['search']['maxDepth'], 1)
        self.assertGreaterEqual(result['search']['totalMaxDepth'], result['plies'])
        self.assertGreaterEqual(result['search']['cycles'], 0)
        self.assertTrue(examples)
        self.assertTrue(all(example['value'] == (1 if example['observation']['turn'] == result['winner'] else -1)
                            for example in examples))
        self.assertEqual(verify_game(self.engine, 'race', result, examples), len(examples))
        with self.assertRaisesRegex(ValueError, 'outcome label'):
            verify_game(self.engine, 'race', result,
                        [dict(examples[0], value=-examples[0]['value']), *examples[1:]])
        with self.assertRaisesRegex(ValueError, 'policy target'):
            verify_game(self.engine, 'race', result,
                        [dict(examples[0], policy=[-1] * len(examples[0]['policy'])), *examples[1:]])
        before = [parameter.detach().clone() for parameter in self.model.parameters()]
        metrics = measure(self.model, examples)
        self.assertEqual(metrics['positions'], len(examples))
        self.assertTrue(math.isfinite(metrics['valueMse']))
        self.assertTrue(all(torch.equal(old, new) for old, new in zip(before, self.model.parameters())))
        self.assertIsNone(measure(self.model, []))
        draw = dict(examples[0], value=0)
        self.assertIsNone(measure(self.model, [draw])['decisiveSignAccuracy'])
        optimizer = torch.optim.Adam(self.model.parameters(), lr=0.001)
        loss = train_batch(self.model, optimizer, examples)
        self.assertTrue(math.isfinite(loss))
        self.assertTrue(any(not torch.equal(old, new) for old, new in zip(before, self.model.parameters())))
        value_weights = [parameter.detach().clone() for parameter in self.model.value.parameters()]
        fresh_optimizer = torch.optim.Adam(self.model.parameters(), lr=0.001)
        train_batch(self.model, fresh_optimizer, examples, value_loss_weight=0)
        self.assertTrue(all(torch.equal(old, new) for old, new in zip(value_weights, self.model.value.parameters())))
        truncated, result = self_play(self.engine, self.model, 2, 1, self.rng)
        self.assertEqual(result['outcome'], 'unfinished')
        self.assertEqual(result['plies'], 1)
        self.assertEqual(len(result['moves']), 1)
        self.assertFalse(result['final']['terminal'])
        self.assertEqual(truncated, [])
        self.assertEqual(verify_game(self.engine, 'initial', result, truncated), 0)
        with self.assertRaisesRegex(ValueError, 'fabricated labels'):
            verify_game(self.engine, 'initial', result, examples[:1])
        self.assertIsNone(train_batch(self.model, optimizer, truncated))
        capped, cap_result = self_play(self.engine, self.model, 2, 1, self.rng, capped_as_draw=True)
        self.assertEqual(verify_game(self.engine, 'initial', cap_result, capped), 1)
        self.assertEqual(capped[0]['value'], 0)
        for invalid in (dict(cap_result, winner=0), dict(cap_result, cappedLabel=1)):
            with self.assertRaisesRegex(ValueError, 'cannot claim'):
                verify_game(self.engine, 'initial', invalid, capped)


if __name__ == '__main__':
    unittest.main()
