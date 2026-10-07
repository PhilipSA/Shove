# AlphaZero in the browser app

Branch `experiment/alphazero-browser`, based on upstream `origin/develop` `569ba7f`.
Pick **alphaZeroAi** for either side on the Play screen, upload an exported
`weights.json`, and play it against a human, MinMax, Random or another AlphaZero
model. Nothing is committed or merged.

## Setup, build, run

Use the Flutter SDK in `~/develop/flutter` (the script puts it on `PATH`; set
`FLUTTER_HOME` to override). Run these from this directory:

```bash
# Normal development: both compiled workers are supplied, like upstream MinMax.
export PATH="$HOME/develop/flutter/bin:$PATH"
flutter run -d chrome

# Only after changing AI/search/rules/worker source: rebuild BOTH workers.
bash tool/alpha_zero_web.sh workers

# Rebuild workers and the release web app -> build/web:
bash tool/alpha_zero_web.sh build-web

# Alternatively serve the already built app, then open http://127.0.0.1:8787:
python3 -m http.server --bind 127.0.0.1 --directory build/web 8787
```

Both `web/alpha_zero_worker.js` and MinMax's compiled worker are included as
versionable generated artifacts. No worker build is needed just to run the app
or upload different weights. Rerun `workers` (or `build-web`) after changing AI,
game-rule or worker source, and include the regenerated artifacts with that change.
Flutter hot reload does not rebuild these workers. A missing or stale worker
shows up as an AI error on the board, not a hang.

## Embedded weights (web and native Windows)

Place an exported model at `assets/weights.json` before running or building.
The existing `assets/` entry in `pubspec.yaml` includes it automatically; no
extra build flag or worker rebuild is needed. On Windows, run
`flutter build windows` from a Windows machine. The model is loaded through
Flutter's asset bundle and searches run in native Dart isolates.

When bundled, the model is used for both AlphaZero sides and replaces the
upload controls. An invalid bundled model shows an error and blocks AlphaZero
play. Without that file, the existing browser upload flow is unchanged (native
file picking is not supported). Rebuild after adding, replacing or removing it.

## Which file to upload

`weights.json` in format `shove-az-dart-v1`, exported by the training checkout's
`experiments/alphazero/run_dart.sh export` (see its `DART_RUNNER.md`). The
reviewed champion is `experiments/alphazero/evidence/dart-001/weights.json`
(~1.8 MB, local-policy head, checkpoint `f0c4151f80ff…`).

- The file is read locally with the browser's file picker. It is never sent to a
  server, and it is not part of the app build.
- The app validates the format, encoding, every tensor shape and value, and the rules
  hash. It shows the file name, size, architecture (local-policy or legacy head),
  checkpoint and rules hash, or a readable error. **Start Game** stays disabled
  until each AlphaZero side has a valid model.
- The model must report rules hash `baea03fb82e4…`, the training checkout's
  `lib/game_objects` hash. Upstream's hash differs only because of unrelated files
  (notation, the DTO player factory, the Squadron service). The rules sources
  (`shove_game.dart`, `shove_game_move*.dart`, `shove_piece.dart`, `shove_square.dart`,
  `piece_type.dart`, `shove_direction.dart`, `shove_player.dart`) are byte-identical.
  Recheck this if the rules change on either side.
- Without embedded weights, each side keeps its own model, so two checkpoints can play each other. Rematch
  reuses the same players and models. Going back and starting again creates new
  players from the uploaded models.

## How it plays

- `lib/ai/alpha_zero/az_network.dart` and `alpha_zero_ai.dart` are copies of the
  training checkout's `dart_network.dart` / `dart_player.dart`. The search and
  network are unchanged. Only worker delegation was added.
- Each AlphaZero player owns one dedicated web worker (`alpha_zero_worker.js`, plain
  `package:web`, not Squadron). The worker parses the weights once.
- Every move request sends **all actual moves** as `[from, to, actor-or-64]` tuples.
  The worker replays them on a fresh standard game (same player names, White first),
  matching each tuple against the legal moves. It then checks that the final board,
  stuns and side to move match the caller's game. So repetition history and undo
  information are exact. `ShoveGame.fromDto` is not used. Custom starting positions
  (puzzles, edited boards) are rejected with an error.
- The search gets the same 3-second clock as browser MinMax, with replay time
  counted inside it. The simulation cap is effectively unlimited. If the worker
  fails, times out (think time + 20 s) or returns an illegal move, the worker is
  discarded and the board shows the error with **Retry AI**. The AI loop does not
  retry by itself, and Undo still works.
- Closing the board stops a running search and terminates the workers. On non-web
  platforms each search runs in a short-lived isolate instead.

## Comparison caveats

- Not a production match-runner result. Browser timing depends on the tab, machine
  load and JS engine. MinMax starts a new Squadron worker for every move, while
  AlphaZero keeps its worker, so per-move overheads differ.
- **Active training on this machine consumes CPU.** Don't compare strength or speed
  while `loop.py` runs, and swap colours across games.
- No interactive browser run was done for this change. The app was built, not launched.

## Verification done

- `flutter test`: 167 passed (146 upstream + 21 new in
  `test/alpha_zero_test.dart`, `test/alpha_zero_ui_test.dart` and
  `test/alpha_zero_repetition_test.dart`). The new tests cover:
  - upload validation, Start Game blocking and picker errors;
  - PyTorch-reference logit/value parity;
  - exact replay with throws/hook pulls, stuns and both turns, and repetition draws;
  - custom-start and tampering rejection;
  - legal, non-mutating moves for both colours, through both the in-process and the
    isolate paths;
  - DTO fallback, error/retry/undo and dispose/stop lifecycle, rematch identity,
    and preventing duplicate searches when AI processing is requested twice;
  - preserving a real repetition draw inside AlphaZero's private search copy.
- The real-weights tests need the frozen files copied into the ignored
  `test/alpha_zero_fixtures/`. Without them, a synthetic model is used and the
  parity test is skipped:

  ```bash
  mkdir -p test/alpha_zero_fixtures
  cp ../Shove-alphazero/experiments/alphazero/evidence/dart-001/{weights,reference,history-reference}.json test/alpha_zero_fixtures/
  ```

- `flutter analyze`: only the 6 findings already present upstream.
- Initial `bash tool/alpha_zero_web.sh build-web`: both workers and the release app
  built. After the repetition-copy fix, the AlphaZero worker was recompiled and
  verified, and its assets copied into `build/web`. A full post-fix release app
  rebuild and full analysis timed out under machine load; not claimed to pass.

## Python/Dart/browser-worker fidelity check

The training checkout's `experiments/alphazero/verify_dart_runtime.py` tested frozen
`dart-002` weights. Native Dart and JavaScript had identical Python visit counts on
all 88 searches (32/256/1024 simulations, both turns, 17 cycle cases, 4 immediate-win
cases). All shipped-worker choices were Python max-visit actions. Predictions
matched within ~1.5e-6. JavaScript ran in Node, not Chrome, so this is implementation
fidelity at fixed simulation budgets, not equal speed or equal-time playing strength.
Evidence is in the training checkout's `evidence/runtime-parity-002-fixed/summary.json`.

This check exposed and fixed a real history-copy bug. `ShoveGame.copy()` freezes
historical square piece IDs, altering repetition equality compared with real play.
AlphaZero now rebinds its private move history to the private board; shared rules,
MinMax and the Python trainer remain unchanged. An independent regression test
checks the recorded failing history without relying on learned weights.
Restart Flutter and refresh Chrome to replace any already-loaded old worker.
Continue uploading the same `dart-002/weights.json`; no new model is required.
