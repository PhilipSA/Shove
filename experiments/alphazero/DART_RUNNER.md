# Frozen AlphaZero in Dart

All new code stays in this experiment. No Python subprocess is needed to play:
`dart_network.dart` implements the trained network, and `dart_player.dart` implements
`AlphaZeroAi extends IPlayer implements IAi`. Both files are browser-compatible.
The JSON-lines command-line wrapper alone imports `dart:io`.

## Export a champion

Training can keep running: the exporter reads one atomically published checkpoint,
freezes its bytes, validates rules/encoding, and writes a NEW output directory.
It never trains or rebuilds the live engine. The optional reference check uses its
own engine process and one PyTorch thread.

```bash
bash experiments/alphazero/run_dart.sh export \
  .dart_tool/az-long-004/champion.pt experiments/alphazero/evidence/dart-new \
  --reference
bash experiments/alphazero/run_dart.sh test \
  experiments/alphazero/evidence/dart-new/weights.json \
  experiments/alphazero/evidence/dart-new/reference.json
```

Weights are JSON (~1.8 MB for the local-policy champion). The exported model
supports both legacy and local-policy variants. It rejects wrong shapes, nonfinite
weights, incompatible encoding/format and an optional expected rules hash.
Export enforces this checkout's rules hash. Loading in another worktree does NOT
automatically hash its Dart sources: confirm its actual rules are identical.
The export includes the checkpoint's SHA-256 and rules hash for provenance.

## Native runner

Use the bundled project directory, not its files overlaid on another worktree.
Run `flutter pub get` there first if dependencies have not been resolved.

```bash
bash experiments/alphazero/run_dart.sh build
.dart_tool/alphazero_dart_runner path/to/weights.json 256
```

One JSON request/response per line; protocol matches the Python service:
`reset` (fixture/turn/seed), `observe`, `push` (move tuple), `pop`, `choose`.
Also supports `predict`. Choosing does not advance the actual game.

Moves are `[from, to, actor]`; square IDs are `row * 8 + column`, absent actor=64.
Feed both players' moves and all opening moves in order. The engine maintains
real history; search works on a copy and leaves the caller untouched.

The first numeric argument is a simulation cap; the optional second is a
millisecond deadline. For an approximately three-second search rather than a
256-simulation search:

```bash
.dart_tool/alphazero_dart_runner path/to/weights.json 1000000000 3000
```

The deadline includes copying/root expansion, is checked between simulations,
and always allows one completed simulation. Root expansion/one simulation may
overrun. It is not a hard real-time timeout. Don't run timed strength/performance
matches concurrently with training on the same machine.

## Use the AI interface in another worktree

Copy `dart_network.dart` and `dart_player.dart` under that worktree's experiment
folder, and load the exported weights once. No player factory change is needed
for a native runner that constructs the player directly:

```dart
final network = DartPolicyValue.fromJson(await File(weightsPath).readAsString());
final az = AlphaZeroAi('AlphaZero', true,
    network: network,
    simulations: 1000000000,
    thinkTime: const Duration(seconds: 3));
final move = await az.makeMove(game);
// The match runner, not the AI, applies game.move(move).
```

`lastSearch` exposes actual simulations, maximum path depth, cycle hits, root
value and raw/returned-policy visits. These are NOT MinMax completed-depth metrics.
Search uses the frozen champion, no root noise, uniform seeded max-visit tie
selection, cycle guard, exact terminal values and the Python immediate-win override.
Dart and NumPy RNGs differ: identical seeds do not imply identical tied moves.

## Chrome next

Load weights from an asset and initialize one model per worker. Add a worker
endpoint carrying the complete game state AND history, a worker-backed AI wrapper,
and player selection/factory integration. Do not use the UI DTO to reconstruct
history blindly: preserve real repetition adjudication and verify replay parity.
`makeMove` is async for the interface but its calculation is synchronous; calling
it on the UI thread will block rendering. Native timed matches should also use
isolates when parallelism/responsiveness is required.

The network/player have compiled to JavaScript and passed inference checks in
Node, plus a legal interface move without changing the game. This is NOT browser
UI/worker integration or a Chrome performance measurement.

## Verified snapshot

`evidence/dart-001` freezes champion SHA-256
`f0c4151f80ff4ac12d068a92cc197305c8953aae1d130399d4aa8d265c61ae31`.
It is a snapshot, not a claim that this checkpoint is stronger than another.

- 70 inference positions, covering both turns, every owner/type/stun input plane,
  actor-bearing moves and missing-actor sentinel. Maximum logit error versus
  PyTorch ~1.53e-6, policy error ~2.10e-7, value error ~5.17e-7.
- 68 searches at 32 simulations, another 68 at 256: exact Python visit counts,
  depth and cycle statistics. Legacy checkpoint: 70 predictions and 68 exact
  256-simulation searches too.
- Three late-game roots with 100/150/180 plies of history at 1024 simulations:
  cycle counts 0/3/38 match Python. After the private-history-copy fix below, all
  three have identical visits. An earlier discrepancy was mistakenly attributed
  to roundoff; frozen history squares were the actual cause.
- Immediate-win selection, terminal rejection, deadline stopping, original-game
  immutability and model rules-hash rejection checked.
- 24 Python tests passed using `run.sh test` in a temporary source copy, so the
  live trainer's engine was not rebuilt. Focused Flutter analysis: no issues.
  Full-workspace analysis timed out; it is not claimed to pass.

Repeat the late-history check (the roundoff allowance is no longer needed):

```bash
bash experiments/alphazero/run_dart.sh test \
  experiments/alphazero/evidence/dart-001/weights.json \
  experiments/alphazero/evidence/dart-001/history-reference.json
```

## Broader runtime verification and repetition fix

`verify_dart_runtime.py` checks frozen weights against the browser worktree's
actual native player, its JavaScript-compiled core and its shipped worker JS.
It runs JavaScript in Node, not Chrome, and does not run timed matches:

```bash
.venv-alphazero/bin/python experiments/alphazero/verify_dart_runtime.py \
  experiments/alphazero/evidence/dart-002 \
  experiments/alphazero/evidence/runtime-parity-new \
  --browser-project ../Shove-alphazero-browser
```

Evidence: `evidence/runtime-parity-002-fixed/summary.json`. With checkpoint
`6cf5b2205e4b…`: 90 inference cases / 40 unique boards, 88 searches at 32/256/1024
simulations, both turns, 17 cycle cases and 4 discovered-immediate-win cases.
Native and JavaScript visit counts match Python exactly in every search;
all shipped-worker choices are Python max-visit actions (ties can pick different
moves because RNG implementations differ). Maximum logit/policy/value errors:
1.47e-6 / 2.91e-7 / 5.82e-7; root value error at most 1.91e-7.

The initial broader check exposed a real bug: `ShoveGame.copy()` detaches historical
squares and freezes their piece IDs, but repetition equality compares live square
objects including piece IDs. AlphaZero's `copyAlphaZeroSearchGame` now rebinds
history to its own private board. This preserves real engine adjudication without
changing shared rules or MinMax. The browser worktree has an independent regression
test for the exact failing 80-ply history and 3-ply continuation (no model required).
The initial failing evidence and diagnosis are retained in `runtime-parity-002`.

167 browser-worktree tests passed after the fix. The corrected worker compiled and
was verified in Node, then copied into the existing release build's worker assets.
A full release app rebuild and full analysis timed out under current machine load;
those post-fix checks are not claimed to pass. Restart Flutter/refresh Chrome to
replace any already-running old worker. Weights are unchanged.

No model training behavior, game rules or baseline player was changed. Training continued throughout; short
correctness/compilation checks consumed some CPU, not a separate training job.
