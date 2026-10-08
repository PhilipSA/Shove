# Frozen AlphaZero champion for native testing

This bundle is a standalone directory. Extract it beside, NOT over, your other
worktree. It contains frozen weights, the exact training-run source snapshot,
and the existing macOS Dart engine binary. Nothing reads the live trainer.
`export.json` records checkpoint/source/engine SHA-256 hashes and its origin.

From the extracted `az-champion` directory:

```bash
bash experiments/alphazero/run.sh setup
.venv-alphazero/bin/python experiments/alphazero/champion_service.py --simulations 256
```

Setup downloads dependencies; do it after training if you want no resource
contention. On another OS/architecture, rebuild this bundle's engine ONLY:

```bash
export PATH="${FLUTTER_HOME:-$HOME/develop/flutter}/bin:$PATH"
dart compile exe experiments/alphazero/engine.dart -o .dart_tool/alphazero_engine
```

## Protocol for the other worktree's match adapter

Keep one service process per game. Send one JSON object per line; receive one
JSON response per line. Diagnostics/startup failures go to stderr. EOF shuts down.

- `{"op":"reset","turn":0}`: standard initial position (0 White, 1 Black).
- `{"op":"observe"}`: board, legal moves, turn, terminal/winner/history length.
- `{"op":"choose"}`: returns `move`, `index`, `policy`, search telemetry.
  **Does not play the move.** Search has no root noise and seeded random visit ties.
- `{"op":"push","move":[from,to,actor]}`: plays either player's move.
- `{"op":"pop"}`: undoes one real move.

Squares are `row * 8 + column` (Dart `x * 8 + y`). `actor` is the hook/thrower
square, or 64 if absent. Map actual move squares rather than assuming the two
engines enumerate moves in the same order. Feed ALL moves, including MinMax's
and any seeded opening, to both engines in exactly the same sequence. Stop on
terminal states; attempting to choose a terminal move returns an error.

The other worktree must use the same game rules: verify legal-move sets, turn,
and terminal outcomes agree. The bundle's loader checks its own archived rules;
it cannot automatically verify the other worktree's rules. The service supports
initial/sparse-fixture resets, not arbitrary board replacement, so it preserves
real move/repetition history.

## Evaluation limits

`--simulations` is a FIXED simulation budget, NOT milliseconds. `--seed` controls
ties. This is a native CPU Python service, not a Flutter/web-worker player or a
3-second timed adapter. A fixed-simulation versus timed-MinMax match must report
both budgets and measured move times; it is not an equal-time strength claim.

The bundle does not change MinMax or your existing match runner. Add its adapter
in the destination worktree. Don't run timed matches while training on the same
machine: isolated files do not isolate CPU contention.

Runnable check (uses only this bundle's engine):

```bash
PYTHONPATH=experiments/alphazero .venv-alphazero/bin/python -m unittest test_champion_service
```
