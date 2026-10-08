from contextlib import redirect_stderr
import io
from pathlib import Path
import tempfile
import unittest

import torch

from compare import opening, parse_args, play_game
from train import Engine, FORMAT, PolicyValue, ROOT, load_model, rules_hash


class CheckpointComparisonTests(unittest.TestCase):
    def setUp(self):
        torch.set_num_threads(1)
        torch.manual_seed(1)
        self.model = PolicyValue().eval()
        self.engine = Engine(ROOT / '.dart_tool/alphazero_engine')

    def tearDown(self):
        self.engine.close()

    def test_pair_has_identical_opening_and_model_assignment_swaps(self):
        first, moves = opening(self.engine, 'initial', 20001, 8)
        swapped, other_moves = opening(self.engine, 'initial', 20001, 8)
        self.assertEqual(first, swapped)
        self.assertEqual(moves, other_moves)
        for candidate_white, winner in [(True, 'candidate'), (False, 'baseline')]:
            result = play_game(self.engine, self.model, self.model,
                               candidate_white=candidate_white, seed=1,
                               simulations=64, max_plies=8, opening_plies=0, fixture='race')
            self.assertEqual(result['outcome'], winner)
            self.assertEqual(result['plies'], 1)
            self.assertEqual(result['timing'][winner]['moves'], 1)

    def test_ply_cap_is_unfinished_and_trace_replays(self):
        result = play_game(self.engine, self.model, self.model,
                           candidate_white=True, seed=20001,
                           simulations=2, max_plies=1)
        self.assertEqual(result['outcome'], 'unfinished')
        self.assertEqual(result['reason'], 'plyLimit')
        observation = self.engine.ask('reset')
        for move in result['openingMoves'] + result['moves']:
            observation = self.engine.ask('push', index=observation['moves'].index(move))
        self.assertEqual(observation, result['final'])

    def test_checkpoint_contract_and_argument_guards(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            checkpoint = root / 'model.pt'
            payload = {'format': FORMAT, 'rulesHash': rules_hash(), 'model': self.model.state_dict()}
            torch.save(payload, checkpoint)
            loaded = load_model(checkpoint)
            self.assertTrue(all(torch.equal(a, b) for a, b in zip(self.model.parameters(), loaded.parameters())))
            torch.save(dict(payload, format='old-format'), checkpoint)
            with self.assertRaises(ValueError):
                load_model(checkpoint)
            torch.save(dict(payload, rulesHash='different-rules'), checkpoint)
            with self.assertRaises(ValueError):
                load_model(checkpoint)
            required = ['--candidate', str(checkpoint), '--baseline', str(checkpoint),
                        '--output', str(root / 'new-run')]
            options = parse_args(required)
            self.assertEqual(options.games, 20)
            self.assertEqual(options.max_plies, 300)
            self.assertEqual(options.simulations, 32)
            for extra in [['--games', '3'], ['--simulations', '0'], ['--opening-plies', '-1'], ['--seed', '-1'],
                          ['--candidate-value-scale', 'nan'], ['--baseline-value-scale', '2'],
                          ['--baseline-simulations', '0']]:
                with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                    parse_args(required + extra)
            (root / 'new-run').mkdir()
            with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                parse_args(required)


if __name__ == '__main__':
    unittest.main()
