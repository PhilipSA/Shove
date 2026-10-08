# Isolated AlphaZero-style experiment

Worktree: `../Shove-alphazero`, branch `experiment/alphazero`, based on committed
`0e9e7b9` (including springboard rules). The main checkout's pending AI improvements
are deliberately NOT copied. No app launch, worker build, MinMax changes, rule
changes, or match-runner changes. Python dependencies live in `.venv-alphazero`;
outputs stay in this worktree's ignored `.dart_tool`.

## What exists

- `engine.dart`: JSON-lines bridge using ShoveGame's actual legal moves, move/undo,
  stuns, springboards, and termination/repetition logic. History remains in Dart;
  we do not serialize through the UI DTOs or reimplement rules in Python.
- `train.py`: small CPU policy/value network, PUCT MCTS, exploratory self-play,
  policy training from visit distributions and value training from final results.
  The policy scores only engine-supplied legal moves, including throw/hook actors.
  Fixed validation games use a separate random stream and are never added to replay.
- `audit.py`: replays saved games with exact rules and checks every policy/value
  target against the recorded position and terminal result.
- `compare.py`: frozen checkpoint-versus-checkpoint matches, identical seeded
  openings played twice with model colors swapped; equal fixed MCTS simulations.
- `test_*.py`: encoding/legal-move checks, exact undo restoration, winning moves,
  optimizer updates, paired comparison plumbing, seeded ties, and cap handling.

Board input: 24 **current-player-relative** piece/owner/stun planes. Own pieces
always advance toward row zero; board rows and policy square IDs are reflected for
Black, and there is no absolute-color channel. This prevents trivially learning
"White always wins" from a one-sided dataset. Encoding v2 rejects old v1 checkpoints.
The policy jointly embeds from/to/actor square IDs rather than allocating a huge
output for all possible moves. Value is from the side-to-move perspective, so MCTS
negates values at each ply. No transposition cache: simulations use exact history.
Simulated repetitions of the same board/stuns/side get a neutral search value;
only the Dart engine can adjudicate an actual draw. `--no-cycle-guard` (training)
and per-side comparison flags allow a controlled search ablation. Reports include
maximum MCTS path depth and detected simulated cycles; these are not alpha-beta
completed-depth counters.
Self-play and validation alternate the starting side; this is a training-data
variation, not a change to game rules or the production match runner. After the
first 20 exploratory self-play plies, choose uniformly among moves tied for most
visits using the run's seeded RNG; comparison uses this same tie rule without
root noise. Never use first-index `argmax` to resolve visit ties: it biases play
through the rules engine's enumeration order.

## Commands

From this worktree:

```bash
bash experiments/alphazero/run.sh setup
bash experiments/alphazero/run.sh test

# Tiny end-to-end learning check on an intentionally trivial endgame.
bash experiments/alphazero/run.sh train --fixture race --games 4 --iterations 2 \
  --simulations 64 --max-plies 8 --output .dart_tool/az-race-check

# Actual full-board self-play. Start small; this is NOT a strength evaluation.
bash experiments/alphazero/run.sh train --games 2 --simulations 16 --max-plies 300 \
  --output .dart_tool/az-initial-001

# Short learning experiment with held-out games and several gradient updates.
bash experiments/alphazero/run.sh train --games 4 --iterations 3 --updates 16 \
  --validation-games 4 --simulations 32 --max-plies 300 --seed 4 \
  --output .dart_tool/az-relative-learning-003
bash experiments/alphazero/run.sh audit .dart_tool/az-relative-learning-003

# Cheap before/after pilot; NOT the production 3000-ms/move comparison.
bash experiments/alphazero/run.sh compare \
  --candidate .dart_tool/az-relative-learning-003/model.pt \
  --baseline .dart_tool/az-relative-learning-003/initial-model.pt \
  --games 20 --simulations 32 --opening-plies 8 --max-plies 300 --seed 20011 \
  --output .dart_tool/az-before-after-003

# Continue v2 weights (optimizer/replay start fresh), always using a new output path.
bash experiments/alphazero/run.sh train --checkpoint .dart_tool/az-initial-001/model.pt \
  --games 2 --output .dart_tool/az-initial-002
```

The helper rebuilds the native bridge before tests/training/audits/comparisons,
avoiding stale rules.
PyTorch is CPU-only at runtime and limited to one thread; no background training
job is started. Still avoid running training concurrently with timed AI matches:
it consumes CPU even in a separate worktree.

Outputs: manifest with settings/Git revision/rules and source hashes, an archived
source snapshot, per-game move traces (including unfinished games), per-iteration
JSONL training positions and outcome reports, and `model.pt`. New runs also save
`initial-model.pt` for a frozen before/after comparison. Reports include winner
counts, gradient-update counts, fixed validation policy cross-entropy/value MSE,
and trivial always-White/always-Black value baselines. These are learning diagnostics,
NOT playing-strength measurements. Two validation games are a plumbing check,
not a statistically reliable generalization test; don't tune to their outcomes.
Checkpoints reject mismatched rules or encoding versions. Existing
output directories are rejected so earlier evidence is not overwritten. Preserve
accepted evidence outside `.dart_tool` before cleanup.

## Limits — deliberately not a production player

- The network sees the board and turn, not full repetition history. This is an
  approximate/non-Markov value function, although simulated game endings are
  adjudicated using exact history. Add history inputs if this affects learning.
- One small gradient batch per iteration by default (`--updates` changes it),
  bounded 4096-position in-memory replay;
  variable legal-move lists are processed one position at a time. It is a pipeline
  experiment, not a throughput-optimized trainer or a full AlphaZero reproduction.
- A ply-capped game is **unfinished**, not a draw. Its positions are discarded
  rather than trained with fabricated draw labels. Sparse results can mean zero
  training examples and no weight update; inspect `replayPositions` and `loss`.
- The `race` fixture checks training plumbing only. Learning to solve it is not
  evidence of full-board strength. Initial priors/value start random, not from GPT
  or the hand-written evaluator.
- Checkpoint comparison is serial and fixed-simulation, not timed. Equal budgets
  isolate the weights. The original 32-simulation pilot (~8–10 ms/move) was very
  shallow; newer experiments use 256 simulations (~90–100 ms/move). Neither can
  establish strength against a 3000-ms MinMax/ImprovedAi. The existing
  production budget and match runner are unchanged. Errors invalidate a screen;
  unfinished games remain separate from draws.
- Experimental champion selection now exists, but no timed `makeMove` adapter,
  web-worker integration, GPU batching, or claim against any production AI.
  Passing a gate on one curriculum does not prove full-board strength.

## First observations

Three integration tests and all 32 committed rules tests passed. An initial
2-game/16-simulation/100-ply batch ended with both games unfinished: zero labeled
positions and no learning update. That is useful evidence of the sparse-outcome
problem, not an improvement. The sparse `race` fixture separately verifies actual
self-play labels and gradient updates: `.dart_tool/az-race-check` completed eight
toy games across two iterations, retained nine labeled positions, and performed
two weight updates. Analysis has only the six existing warning/info findings.

## Continued experiment

- `.dart_tool/az-initial-300`: both full-board games completed, generating 326
  positions and a gradient update. A 100-ply cap had been too short for this sample.
- `.dart_tool/az-learning-001` (old absolute-color encoding): all five completed
  games, including validation, were won by White. Validation MSE fell near zero,
  but a constant White-wins prediction already solves those labels. Rejected as
  useful evidence of positional learning; this motivated relative encoding.
- `.dart_tool/az-relative-learning-001`: four training games completed (White 2,
  Black 2), yielding 382 positions and 16 gradient updates. Two fixed validation
  games yielded 313 additional positions, excluded from training. All six traces
  and 695 targets passed exact replay/label auditing.
- Validation value MSE changed **0.999 → 1.026**: no demonstrated generalization
  gain. Policy cross-entropy changed only **3.5173 → 3.5161**. Both validation games
  were won by White, so that tiny set is still unrepresentative; baseline metrics
  now make this visible instead of disguising it as success.
- Four integration tests passed; analysis still has only the six existing findings.

## Larger batch and direct before/after pilot

- `.dart_tool/az-relative-learning-002`: 12 completed training games (White 8,
  Black 4), **1418 training positions**, 48 gradient batches. Four fixed validation
  games produced 582 positions, all White wins. All 16 traces and **2000 targets**
  passed exact replay/label auditing. Value MSE fell **1.009 → 0.806**, but policy
  cross-entropy worsened **3.524 → 3.540**; the biased tiny validation set is not
  evidence of stronger play.
- `.dart_tool/az-before-after-001`: same run's trained versus frozen untrained
  weights, 20 paired games / 32 simulations / 8 opening plies / 300-ply cap /
  seed 20001 / serial. Trained **0 wins**, untrained **1**, **19 unfinished**, no
  draws/errors. Several unfinished traces repeated an eight-ply cycle.
- Diagnosis: 298/582 validation positions had ties for the most visits. First-index
  `argmax` systematically favored enumerated pieces. In one stalled comparison
  trace the baseline had 10–11 tied moves, while the trained model assigned nearly
  all visits to a looping move. Tie bias is not the only problem.
- Shared seeded random tie selection was added to self-play and comparison and
  tested for reproducibility, coverage of tied maxima, and exclusion of inferior
  moves. No weights were changed for the following repeat screen.
- `.dart_tool/az-before-after-002-random-ties`: same checkpoints, openings, and
  budgets under the corrected tie rule. Trained **2 wins**, untrained **11**,
  **7 unfinished**, no draws/errors. Mean/max move time: trained **9.53/31.29 ms**,
  untrained **8.00/25.51 ms**. This is an exploratory failure to promote, not a
  statistically certified ranking. Both checkpoints are copied into the comparison
  archive so future training cannot change the opponent.
- Eight experiment integration tests and 24 existing focused AI/search tests
  passed. All 40 comparison traces, paired opening states, outcome attribution,
  and unchanged checkpoint hashes were independently verified by replay. Analysis
  retains only the six existing warnings/info findings. Nothing was merged or
  promoted.

## Corrected-protocol retraining

- `.dart_tool/az-relative-learning-003-corrected-ties`: only the self-play tie
  protocol changed relative to learning-002. Same architecture, seed 3, four games
  per iteration, three iterations, 16 gradient batches per iteration, four fixed
  validation games, 32 simulations, and 300-ply cap. Starting tensors were verified
  identical to learning-002, so this was not a different random initialization.
- All 12 training games completed (White 5, Black 7), producing **1587 positions**
  and 48 gradient batches. Four completed validation games produced 732 positions,
  all Black wins, excluded from training. All 16 traces and **2319 targets** passed
  exact replay/label auditing. Validation MSE **1.009 → 1.086**, cross-entropy
  **3.546 → 3.550**: no demonstrated generalization improvement. This validation
  set differs from learning-002 because the move protocol changed; do not compare
  raw loss values across those two datasets.
- `.dart_tool/az-before-after-003-corrected-ties`: trained versus its own frozen
  starting weights, same fixed-simulation pilot settings as before but **fresh
  opening seeds 20011–20020**, color-swapped pairs. Trained **0 wins**, untrained
  **11**, **9 unfinished**, no draws/errors. Mean/max move time: trained
  **10.30/35.12 ms**, untrained **8.46/29.56 ms**. Another failure to promote—not
  evidence that the AlphaZero approach itself cannot work.
- All 20 comparison traces, paired opening states, and outcome attribution were
  independently replay-verified. The nine unfinished games had 8–19 exact repeated
  board/stun/side-to-move positions among 150 candidate turns each. This supports
  investigating search cycles, but does not establish them as the sole cause.
- All eight experiment integration tests passed again. No source behavior changed
  during this experiment; only new artifacts and this record were added.

## AlphaZero-only search and training diagnostics

No MinMax opponent adapter was built. An unused detached opponent worktree was
removed after the scope clarification; only this experiment is being developed.

- Added a simulated-cycle neutral-value guard and regression checks: it restores
  engine state, does not fabricate actual game termination, and gives genuine
  terminal states priority. Search telemetry records simulations, maximum path
  depth, cycle hits, and root value. Self-play traces also record depth/cycles.
- `.dart_tool/az-cycle-ablation-001`: same frozen learned checkpoint on both
  sides, candidate guard on / baseline off, 20 paired games at 32 simulations,
  seeds 20021–20030. **7–7, 6 unfinished**, no errors. Both sides detected zero
  cycles; mean maximum path was only **1.57 plies**. No measured benefit at that
  budget, because search barely gets past the root.
- `.dart_tool/az-depth-probe-001.json`: eight identical opening positions, same
  frozen weights, exact restoration checked. Budgets 32/256/1024 had mean maximum
  paths **3.00/4.38/5.38 plies**, costing **8.8/94.2/415.9 ms** respectively.
  These are identical-position depth/throughput probes, not playing-strength tests.
- `.dart_tool/az-relative-learning-004-deeper`: 256-simulation self-play, same
  seed/architecture/game count/update count as the prior 32-simulation run, cycle
  guard on. All 12 training games completed (6 wins per color), producing **1564
  positions** plus 852 held-out positions. All **2416 targets** and 16 traces
  passed auditing. MSE **1.010 → 1.076**; policy cross-entropy remained about 3.60.
- `.dart_tool/az-before-after-004-deeper`: learned versus its frozen starting
  weights at equal 256 simulations, seeds 20061–20070. **0 wins / 9 losses /
  11 unfinished**, no errors. Candidate/baseline mean maximum paths **4.24/3.00**,
  candidate cycle hits **3094**. Deeper search alone did not make learning help.
- Added value-estimate calibration/ablation (`--value-scale` in training,
  `--candidate-value-scale` / `--baseline-value-scale` in comparison). These scale
  only non-terminal predictions; real terminal outcomes remain exact and are
  regression-tested. Defaults remain 1.0.
- `.dart_tool/az-value-ablation-001`: same frozen deeper checkpoint on both sides,
  value estimates disabled versus enabled, eight paired 256-simulation games,
  seeds 20081–20084. **2–2, 4 unfinished**, no errors: inconclusive, so disabling
  the value head was not adopted as a stronger player.
- `.dart_tool/az-gradient-probe-001.json`: fixed 64-position batch, shared-encoder
  gradients measured separately for policy/value losses. Value-to-policy norm
  ratios were **101.5×** at initialization and **64.7×** after deeper training.
  This motivated testing loss balancing, rather than assuming lower combined
  training loss means the policy is learning.
- `--value-loss-weight` now controls the value contribution during optimization
  only (default 1.0). It does not rescale inference or terminal outcomes. Tests
  verify that zero weight does not update the value-head parameters with a fresh
  optimizer, while policy training still runs.
- `.dart_tool/az-relative-learning-005-balanced-loss`: only value loss weight
  changed to **0.01** relative to learning-004. Initial tensors, held-out traces,
  and first self-play batch were verified byte-/tensor-identical. All 12 games
  completed (White 5, Black 7), producing **2011 training positions**, plus the
  same 852 validation positions. All **2863 targets** passed auditing. Validation
  MSE **1.010 → 0.972**, policy cross-entropy **3.6026 → 3.6034**: the value metric
  improved modestly, but policy generalization still showed no improvement.
- `.dart_tool/az-before-after-005-balanced-loss`: equal 256-simulation comparison
  against its own frozen starting weights, fresh seeds 20091–20100. **3 wins /
  15 losses / 2 unfinished**, no errors. Mean/max move time: learned
  **89.23/170.05 ms**, untrained **96.49/385.35 ms**. Not promoted. These are new
  openings, so the reduced unfinished count is not a controlled comparison with
  the prior match batch.

## Fixed-data check and persistent champion loop

`fit.py` learned a fixed 32-position batch in 1000 updates: policy KL
**0.0679 → 0.000874**, value MSE **1.021 → 0.0000188**. This proves basic
learnability, not generalization; that memorized checkpoint is never selected as
champion. The existing architecture was retained.

`loop.py` now keeps a separate champion and continuously trained learner, bounded
4096-position replay, Adam state, and RNG state. New games come from the champion;
rejected learners retain their training. Resume from `state.pt` into a **new**
output directory. Checkpoints/state are atomically published. Automatic promotion
is confined to this experiment; there is no merge/app integration.

The gate uses fresh color-swapped opening pairs and a one-sided paired sign test
at p≤0.05. Unfinished pairs pessimistically count against acceptance, without
fabricating actual losses/draws. Errors invalidate the gate. This is a per-gate
experimental criterion, not a guarantee of lifelong monotonic improvement across
an unlimited sequence of tests.

The first full-board loop (`az-champion-loop-001`) produced 756 positions, trained
128 batches, then scored **1–9 with 10 unfinished**. The champion was retained.

## First confirmed learning gain: varied sparse endgames

The new `endgame` starting-position generator places one shover and one
blocker/leaper per side. Shovers start 2–5 rows from their goal; columns, auxiliary
piece types/locations, and starting side vary. It uses the actual Dart movement,
stun, capture, undo, and termination rules—no invented reward labels or rule changes.
This is a four-piece curriculum, not the full game and not all six piece types.

Training uses even fixture seeds; held-out comparisons use odd fixture seeds.
All canonical board/side/stun inputs used for endgame training are fingerprinted
and retained in resumable state, including positions evicted from replay. A gate
root that overlaps this history invalidates the gate.

```bash
bash experiments/alphazero/run.sh loop \
  --checkpoint .dart_tool/az-relative-learning-005-balanced-loss/initial-model.pt \
  --fixture endgame --rounds 3 --games 24 --updates 128 --gate-games 20 \
  --simulations 256 --gate-simulations 32 --max-plies 100 --opening-plies 0 \
  --seed 43 --output .dart_tool/az-endgame-loop-001

# Resume all learner/optimizer/replay/RNG state, not just the model weights.
# Use a fresh output directory; do not run this alongside timed main-AI matches.
bash experiments/alphazero/run.sh loop \
  --resume .dart_tool/az-endgame-loop-001/state.pt \
  --fixture endgame --rounds 1 --games 24 --updates 128 --gate-games 20 \
  --simulations 256 --gate-simulations 32 --max-plies 100 --opening-plies 0 \
  --output .dart_tool/az-endgame-loop-002
```

Results from `.dart_tool/az-endgame-loop-001`:

- **72 games, 71 completed, 1 unfinished**, **1509 audited positions**, 384 batches.
  The unfinished game's positions were excluded from training.
- All rounds used 256 simulations to generate teaching targets; **both players**
  in every gate had the same 32-simulation budget. This tests whether learning
  compresses stronger search, not an unequal-budget matchup.
- Gate scores: **13–7**, **14–6**, **20–0**. First two candidates were rejected
  (paired p=0.125/0.0625), final candidate promoted **inside the experiment only**
  (10 pair wins, paired p=0.000977).
- Independent frozen-checkpoint confirmation: `az-endgame-confirm-001`, 40 games
  on 20 fresh seeded positions (200101–200120), colors swapped, equal 32
  simulations, no random opening plies. **36 wins / 4 losses / 0 draws /
  0 unfinished / 0 errors** versus the original untrained checkpoint. Sixteen
  pair wins, zero pair losses, four tied pairs; paired p=0.0000153.
- Confirmed mean move time: learned **6.40 ms**, untrained **6.70 ms**. This is
  not a timed production benchmark or a comparison against MinMax.
- All 72 self-play traces, 1509 targets, and **100 comparison traces** were
  independently replay-audited. All held-out roots were checked against the full
  canonical training-position registry. Published champion/learner/state weights
  matched after promotion. Audit summary is saved alongside training artifacts.
- **14 tests pass**; Flutter analysis retains the same six existing findings.

Accepted checkpoint, state, complete traces, and source snapshots are also copied
under ignored `experiments/alphazero/evidence/endgame-001/`, outside `.dart_tool`,
so Flutter cleanup does not destroy this milestone.

This is the first confirmed improvement over starting weights **within the sparse
endgame distribution**. It is one champion replacement, not proof of sustained
multi-generation improvement. Next: broaden to more pieces and piece types,
retain unseen-endgame regression gates, and then mix in full-board self-play.
Do not scale to massive full-board training or claim MinMax competitiveness yet.


## Broader curriculum: six and eight pieces

Added `endgame6` (one shover + two distinct auxiliary types per side) and
`endgame8` (two shovers + two distinct auxiliary types per side). Auxiliary
pieces are sampled from blocker/leaper/charger/hook/thrower, so the distribution
covers all six types, including actor-bearing moves. The original `endgame`
generator remains exactly reproducible. Model architecture/encoding and actual
rules remain unchanged. All sparse fixtures use the same even-training /
odd-held-out seed split and canonical historical training-overlap checks.

`loop --regression-fixture endgame --regression-games 20` adds a conditional
retention screen after a candidate passes its primary gate. Both players use the
same gate budget. It requires no unfinished games and candidate wins at least
baseline wins. This is a conservative finite-sample screen, not a statistical
non-inferiority guarantee. Regression seeds are fresh and advance the persisted
seed cursor. Pairing/errors and historical input overlaps invalidate the screen.

Continuing from the accepted four-piece champion, retaining optimizer/replay/RNG:

- `az-endgame6-loop-001`: three rounds, **72 completed games / 776 new targets**,
  384 batches. Gate scores **8–11 + 1 unfinished**, **13–7**, **9–9 + 2 unfinished**.
  No candidate passed. Tested at equal 32 simulations; teachers used 256.
- `az-endgame8-loop-001`: two rounds, **48 completed games / 474 targets**, 256
  batches. Gate scores **10–10**, then **13–5 + 2 real engine-adjudicated draws**.
  Last paired p=0.0625; candidate was NOT promoted. Draws are not cap outcomes.
- `az-endgame8-loop-002`: one additional predeclared round with a larger fresh
  40-game gate, **24 completed games / 235 targets**, 128 batches. Candidate
  **24–16**, no draws/caps/errors; paired p=0.171875 (7 pair wins, 3 losses, 10 ties).
  Also rejected: more individual wins do not imply sufficient paired evidence.
- Independent four-piece retention test, `az-broader-regression-001`: final
  candidate versus the preserved champion on 40 fresh color-swapped games,
  equal 32 simulations. **20–19 + 1 unfinished**, no errors. This also fails the
  configured conservative retention screen; no claim of proven forgetting or
  proven non-inferiority from this small sample.
- Combined **144 additional completed self-play games**, **1485 new audited
  targets**, **768 batches**. Replay now contains **2994 positions**. All 144
  training traces and **180 comparison traces** were independently replay-audited,
  including actual outcome attribution and held-out root fingerprints.
- The published champion is tensor-identical to the earlier accepted four-piece
  checkpoint. Failed candidates, optimizer and replay remain resumable, but
  nothing was promoted into the app or main checkout.
- **16 tests pass** (generator type coverage/actors/reproducibility/undo plus
  regression-gate checks). Flutter analysis has the same six existing findings.

Artifacts/state/source snapshots are preserved outside `.dart_tool` under ignored
`experiments/alphazero/evidence/broader-001/`. Resume the newest `eight-002/state.pt`
into a new output directory; it contains the learner's extra training, while its
champion is still the four-piece champion.

Next hypothesis: use more interaction-focused tactical positions to teach the new
piece mechanics, rather than immediately adding full-board games or treating
near-goal race victories as proof of broad tactical competence. The broader
curriculum is implemented, but a second champion improvement has not been shown.

## Interaction-focused tactics and policy learning experiments

`endgame-tactics` deterministically rejection-samples the existing six-piece
starting-position generator. Seed modulo three selects a legal hook action on a
shover, a legal throw action on an enemy shover, or a long-range charger landing
on an enemy shover. The filter uses the actual legal-move engine, not a second
rules implementation. It guarantees an available interaction, not that the
interaction is uniquely optimal or strategically necessary. Rejection sampling
is bounded at 1024 attempts; the chosen initial board is reproducible from seed
and starting side. Actual game results remain the only value labels.

- `az-tactics-loop-001`: 72 completed games, **646 new targets**, 384 batches.
  Equal 32-simulation gates scored **17–19 + 2 draws + 2 unfinished**,
  **19–18 + 3 unfinished**, and **19–19 + 2 draws**. All rejected.
- Teacher-headroom check `az-tactics-headroom-001`: exactly the **same frozen
  champion weights** on both sides, fresh paired positions, 256 versus 32
  simulations. **29–9 + 1 draw + 1 unfinished**, no errors. Mean move times
  **68.35/6.93 ms**, mean maximum paths **4.43/2.86**. This deliberately unequal
  budget is a planning/teaching diagnostic, NOT a learned-weight strength gain.
  `compare --baseline-simulations` enables this; default checkpoint comparisons
  and every promotion gate still use equal budgets.

The learner can now opt into `loop --local-policy`: a board-aware **residual**
policy head reuses the existing convolutional cell features at the from/to/actor
squares, existing square embeddings, global context, normalized coordinates, and
an actor-valid flag. Its final layer starts at zero, preserving all original
predictions before training. Existing policy/value parameters and Adam moments
are retained, rather than restarting the model. New parameters get fresh Adam
state. There is no hand-coded winning-move score.

The input encoding remains v2; checkpoints carry a `localPolicy` architecture
flag. The shared loader accepts legacy checkpoints without this flag and both
variants; an old archived loader cannot load a new residual checkpoint. Resumable
state records champion/learner variants separately, so an unaccepted residual
learner never silently replaces the legacy champion. Checkpoint writing is now
shared and atomic across training, fitting checks, and champion publication.

- `az-tactics-local-loop-001`: 48 completed games, **387 targets**, 256 batches.
  Gates **18–18 + 2 draws + 2 unfinished**, then **24–15 + 1 unfinished**.
  No promotion. This is a sequential experiment, not a controlled causal
  comparison with prior scores on different opening seeds.
- Inspection showed tactical initial decisions were only **120/4027 ≈ 3%** of
  replay at this point. Short decisive episodes contributed fewer positions than
  long races. `--root-fraction` now reserves a portion of each gradient batch for
  starting decisions, filling the rest from replay without duplicates. It applies
  to all curriculum roots, not just the latest family. Default zero preserves
  uniform replay; set it explicitly when resuming that experiment.
- `az-tactics-root-loop-001`: root fraction 0.5, 48 completed games, **415 targets**,
  256 batches. Gates **23–16 + 1 unfinished**, **23–14 + 1 draw + 2 unfinished**.
  Neither passed. Generalization/playing-strength improvement from the new head
  or sampling scheme is still unproven.

Across these three training batches: **168 completed self-play games / 1448 new
policy-value targets / 896 gradient batches**. Replay reached its 4096-position
cap; historical input fingerprints survive eviction. All 168 self-play traces,
1448 targets, and **320 comparison traces** (including the unequal-budget
headroom check) were independently replay-audited, with real outcome attribution
and held-out root checks. The champion remains tensor-identical to the confirmed
four-piece champion. **19 tests pass**; Flutter analysis retains the same six
existing findings. No full-board training, app launch, or production promotion.

Durable artifacts/source snapshots/state are under ignored
`experiments/alphazero/evidence/tactics-001/`. Resume `root/state.pt` into a fresh
output directory with `--root-fraction 0.5` to continue the latest learner;
its local-policy variant and optimizer are restored automatically. Its champion
is still the earlier legacy model.

Next: measure decision-level imitation on held-out tactical roots, separated by
hook/throw/charge, and distinguish policy compression failure from inaccurate
value estimates and stalled games. Do not infer success from lower fitting loss,
loosen the gate to obtain a promotion, or scale blindly to full-board games.


## Full-board turnaround and bounded training window

The historical sign-test protocol above is no longer the operational promotion
rule. Following review, `loop.py` now uses a **55% score threshold**: wins score 1,
engine draws and unfinished games score 0.5, losses score 0. Errors still
invalidate the screen. The paired sign test remains reported separately; a score
promotion is **not a statistically certified gain**. Setting `--promote-score 0`
uses the latest learner regardless of score. Optional regression screening remains.

Changes: loop value-loss weight defaults to **1.0**; fresh models have the local
policy head; Adam uses configurable L2 decay (default 1e-4); Dirichlet alpha scales
as min(1, 10/legal-move-count). `--workers` enables spawned processes with one
PyTorch thread and one real Dart engine each. Games have independent seeded RNGs;
results/replay are collected in task order. `--fixture` accepts a cyclic list,
with its first fixture used for gates. Replay capacity and wall-clock stopping
are configurable. Legacy states/architecture upgrades remain supported.

`--capped-as-draw` explicitly permits **proxy value targets of zero** for capped
training episodes, contrary to the earlier discard-only policy. Their recorded
outcome is still unfinished, winner is null, and `cappedLabel: 0` distinguishes
these targets from real engine draws. The audit checks this distinction and
rejects winners/nonzero cap labels. This is a finite-horizon training assumption,
not evidence that the actual game is drawn.

Starting from the earlier tactical learner, mixed self-play used two initial-board
episodes for each endgame8/endgame-tactics episode, 8 workers, 256 simulations,
200-ply caps, and proxy cap labels:

- `az-pilot-parallel-002`: four rounds, 256 episodes, 10801 targets, 200 updates
  per round. Equal-256-simulation full-board gates: **42–8 +10 unfinished**,
  **35–11 +1 draw +13 unfinished**, **33–16 +2 draws +9 unfinished** (promoted),
  then **21–26 +3 draws +10 unfinished** (rejected).
- Independent `az-pilot-confirm-002`: new paired eight-ply full-board openings,
  equal 256 simulations; accepted pilot vs exact starting weights **32–3 +5
  unfinished**, no errors. Score 86.25%; the conservative unresolved-pair sign
  test is NOT significant (p=0.0717). Strong observed gain, not a certified claim.
- `az-progress-003`: eight more rounds, 512 episodes, 400 updates/round, gates at
  equal 128 simulations and 40 games. Five promotions and three rejections;
  total retained replay 41662 positions. Latest score **14–10 +3 draws +13
  unfinished**, accepted exactly at 55%.
- Independent `az-anchor-screen-003`: latest champion vs accepted pilot, new
  paired full-board openings, equal 256 simulations and a 300-ply cap:
  **20–4 +16 unfinished**, score 70%. High censoring prevents a strong statistical
  claim and remains a real weakness, rather than being relabelled as draws.

All self-play games are replay-audited by their generating worker. Durable copies
of these states, traces, weights and source snapshots are under
`evidence/fullboard-001/{pilot,confirmation,progress,anchor}`. No app integration
or production-MinMax comparison has been performed.

The frozen-root diagnosis found that the deeper teacher missed three available
immediate wins, twice despite already visiting the terminal winning child. Search
now conditions its final visit policy on **discovered immediate winning children**
when any exist. It spends the same requested simulation budget, performs no extra
probes, and leaves unvisited winning actions undiscovered. Raw visits remain in
`actionVisits`; returned-target visits are `policyVisits` with an explicit
`policySource`. This is exact terminal evidence, not an added heuristic evaluator.
A regression test makes an optimistic alternative accumulate MORE visits and
checks that the discovered immediate win is nevertheless selected. **23 tests pass.**

## Completed training window and final evaluation

`az-long-004` completed its bounded 5.5-hour continuation: **70 additional rounds,
4480 self-play episodes, 323376 targets and 28000 gradient batches**. Outcomes:
2996 reachedGoal, 503 noShoversLeft, 357 actual repetition draws, 624 unfinished
(proxy-labelled zero for training). Eighteen score-gate promotions; the last
accepted champion came from round 78. Rounds 79–81 were rejected. The final state
has 82 lifetime rounds and 60000 replay positions; it includes the newer rejected
learner and optimizer as well as the accepted champion.

Final frozen comparisons (`az-final-screen-004`) use **40 fresh paired full-board
games per opponent, 8 random opening plies, equal 256 simulations, a 300-ply cap,
no root noise and the same terminal-proof policy for both sides**:

| Opponent | Final champion wins | Losses | Engine draws | Unfinished |
| --- | ---: | ---: | ---: | ---: |
| Exact original tactical starting weights | **39** | **0** | 0 | 1 |
| Frozen champion immediately before the long run | 10 | 11 | 1 | 18 |

Against starting weights: 19 pair wins, zero pair losses, one unresolved pair;
conservative worst-case one-sided p=0.0000200. This confirms a full-board gain
against that frozen AlphaZero baseline under this protocol, **not MinMax or timed
production-player strength**. The head-to-head with the pre-run champion is
inconclusive and heavily censored. The long run did NOT demonstrate an additional
playing-strength gain over that already-improved checkpoint. Do not equate its
18 promotions with 18 independently confirmed improvements.

All self-play episodes were rule-replay-audited in workers. The final 80 comparison
traces were independently replay-audited, including opening positions and outcome
attribution. Published champion tensors match the saved state and are finite.
**24 experiment tests pass**, and training source files remained unchanged during
the run. Training has stopped; no background job remains.

Durable accepted model:
`experiments/alphazero/evidence/final-004/training/champion.pt`.
Resumable learner/optimizer/replay:
`experiments/alphazero/evidence/final-004/training/state.pt`.
Complete final traces, model copies, audit and results:
`experiments/alphazero/evidence/final-004/evaluation/`.
The pre-run champion is also retained under `evidence/fullboard-001/progress/`.

The training deliverable is saved and reproducible. There is still no Dart
`AlphaZeroAi`, inference export, web-worker integration or production matchup.
Those are separate work, not silently included in a training-strength claim.
