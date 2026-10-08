import unittest

import numpy as np
import torch

from champion_service import respond
from train import Engine, ROOT, PolicyValue


class ChampionServiceTest(unittest.TestCase):
    def test_choose_push_and_undo_keep_exact_state(self):
        torch.set_num_threads(1)
        engine = Engine(ROOT / '.dart_tool/alphazero_engine')
        try:
            model = PolicyValue(local_policy=True).eval()
            rng = np.random.default_rng(1)
            def call(request):
                return respond(engine, model, request, rng, 2)
            before = call({'op': 'reset'})
            choice = call({'op': 'choose'})
            self.assertIn(choice['move'], before['moves'])
            self.assertEqual(call({'op': 'observe'}), before)
            after = call({'op': 'push', 'move': choice['move']})
            self.assertEqual(after['historyLength'], 1)
            self.assertNotEqual(after['turn'], before['turn'])
            self.assertEqual(call({'op': 'pop'}), before)
            with self.assertRaises(ValueError):
                call({'op': 'push', 'move': [-1, 0, 64]})
            self.assertEqual(call({'op': 'observe'}), before)
        finally:
            engine.close()


if __name__ == '__main__':
    unittest.main()
