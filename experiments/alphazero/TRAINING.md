# Training Shove's AlphaZero

An 85K-parameter neural network that learned to play Shove from scratch — no
hand-coded strategy, no opening books, no human games. It plays by running
Monte Carlo tree search guided by a trained policy/value network, the same
method DeepMind used for chess, shogi and Go in 2017. We ran it on a laptop.

This document covers three levels: running the trainer, changing the
architecture, and understanding what happened during development.

---

## Quick start: train a stronger champion

### Requirements

- Python 3.12+
- PyTorch (CPU is fine — see `requirements.txt`)
- Flutter SDK (for the Dart rules engine)
- ~2 hours for a meaningful training run, ~12 hours for a full one

### Setup

```bash
# From the repo root
bash experiments/alphazero/run.sh setup
```

This creates `.venv-alphazero/`, installs PyTorch and NumPy, and compiles the
native Dart rules engine. The engine is rebuilt automatically before every
training/comparison/audit command.

### Train from scratch

```bash
bash experiments/alphazero/run.sh loop \
  --fixture endgame8,endgame-tactics,initial,initial \
  --rounds 80 --games 64 --updates 400 --gate-games 40 \
  --simulations 256 --gate-simulations 128 \
  --max-plies 200 --opening-plies 8 --workers 8 \
  --capped-as-draw --wall-clock 20000 \
  --seed 1 --output .dart_tool/az-my-run-001
```

This runs the full self-play → train → gate loop. The champion starts random.
Each round plays `--games` self-play episodes using the current champion, trains
the learner on accumulated replay, then tests the learner against the champion
in `--gate-games` color-swapped matches. If the learner scores above 55%, it
becomes the new champion.

Key flags:
- `--fixture`: starting positions to cycle through (mix of endgames and full board)
- `--workers`: parallel self-play processes (one Dart engine each)
- `--simulations`: MCTS budget for self-play (teaching signal quality)
- `--gate-simulations`: MCTS budget for promotion matches (equal for both sides)
- `--capped-as-draw`: treat ply-capped games as draws for training labels
- `--wall-clock`: stop after this many seconds regardless of round count

### Continue from an existing champion

```bash
bash experiments/alphazero/run.sh loop \
  --checkpoint experiments/alphazero/evidence/final-004/training/champion.pt \
  --fixture endgame8,endgame-tactics,initial,initial \
  --rounds 20 --games 64 --updates 400 --gate-games 40 \
  --simulations 256 --gate-simulations 128 \
  --max-plies 200 --opening-plies 8 --workers 8 \
  --capped-as-draw --seed 100 --output .dart_tool/az-continue-001
```

### Resume a stopped run

```bash
bash experiments/alphazero/run.sh loop \
  --resume .dart_tool/az-my-run-001/state.pt \
  [same flags as original] \
  --output .dart_tool/az-my-run-002   # always a new output directory
```

This restores the learner, optimizer, replay buffer, RNG state and champion.
Rejected learners keep their accumulated training.

### Compare two checkpoints

```bash
bash experiments/alphazero/run.sh compare \
  --candidate .dart_tool/az-my-run-001/champion.pt \
  --baseline experiments/alphazero/evidence/final-004/training/champion.pt \
  --games 40 --simulations 256 --opening-plies 8 --max-plies 300 \
  --seed 50001 --output .dart_tool/az-my-comparison
```

Games are played in color-swapped pairs on identical seeded openings.

### Export for the browser

```bash
bash experiments/alphazero/run_dart.sh export \
  .dart_tool/az-my-run-001/champion.pt \
  .dart_tool/az-my-export --reference
```

This produces `weights.json` (~1.8 MB) that `dart_network.dart` loads in the
browser, plus `reference.json` for cross-platform parity verification.

```bash
bash experiments/alphazero/run_dart.sh test \
  .dart_tool/az-my-export/weights.json \
  .dart_tool/az-my-export/reference.json
```

### Verify a run

```bash
bash experiments/alphazero/run.sh audit .dart_tool/az-my-run-001
bash experiments/alphazero/run.sh test
```

The audit replays every saved game with exact rules and checks every
policy/value target against the recorded position and terminal result.

---

## Architecture and diagnostics

### The network: PolicyValue (85K parameters)

```
Input: 24 planes × 8 × 8
  - 24 current-player-relative channels: 6 piece types × 2 owners × 2 stun states
  - Board is always oriented so own pieces advance toward row 0
  - No absolute color channel (prevents learning "White always wins")

Board encoder:
  Conv2d(24→16, 3×3) → ReLU → Conv2d(16→16, 3×3) → ReLU → Flatten → Linear(1024→64) → ReLU

Policy head (joint embedding):
  - 3 square embeddings (from, to, actor) → Embed(65→8) each
  - Concatenated → Linear(24→32) → Tanh
  - Dot product with Linear(64→32) projection of board features
  - Scaled by 1/√32
  - Optional local-policy residual: board features at move squares + geometry → Linear(143→64→1)

Value head:
  Linear(64→1) → Tanh  (from side-to-move perspective)
```

The policy scores only legal moves supplied by the engine. The joint
from/to/actor embedding handles variable move counts without a fixed-size
output. The local-policy residual head adds board-aware per-move features
(convolutional activations at the relevant squares) on top of the global
policy, initialized to zero so it preserves the existing network on upgrade.

### MCTS details

- PUCT exploration constant: 1.5
- Dirichlet noise: α = min(1, 10/legal_moves), weight 0.25 (self-play only)
- Cycle guard: simulated positions that repeat get a neutral value
- Terminal proof: when MCTS discovers an immediate winning child, the returned
  policy concentrates on discovered winners regardless of visit counts
- No transposition table: each simulation traces from root with exact history
- After 20 exploratory plies, ties for most visits are broken uniformly at random

### The training loop

Each round:
1. **Self-play**: champion plays `--games` episodes against itself with root
   noise and exploration. Positions are stored with their MCTS visit
   distributions (policy targets) and the eventual game outcome (value target).
2. **Train**: sample mini-batches from the replay buffer. Policy loss is
   cross-entropy against visit distributions. Value loss is MSE against game
   outcomes. Adam optimizer with configurable L2 decay.
3. **Gate**: the learner plays `--gate-games` against the champion at equal
   simulation budgets, no noise. If it scores ≥55% (wins=1, draws=0.5,
   losses=0), it becomes the new champion. Failed learners keep training.

### Diagnostic tools

| Tool | Purpose |
|------|---------|
| `compare.py` | Head-to-head checkpoint matches on seeded, color-swapped openings |
| `diagnose.py` | Frozen-root analysis: visit distributions, depth, value estimates, immediate-win detection |
| `fit.py` | Memorization check: can the network fit a fixed batch? Tests basic learnability |
| `audit.py` | Replays saved games with exact rules, verifies every target |
| `champion_service.py` | JSON-lines service for integrating with other match runners |
| `verify_dart_runtime.py` | Cross-platform parity: Python vs native Dart vs JavaScript |

### Fixtures (starting positions)

| Fixture | Pieces | Purpose |
|---------|--------|---------|
| `initial` | Full board | Standard game |
| `race` | Trivial endgame | Plumbing check for the training pipeline |
| `endgame` | 4 (1 shover + 1 aux per side) | First learnable curriculum |
| `endgame6` | 6 (1 shover + 2 aux per side) | Broader piece-type coverage |
| `endgame8` | 8 (2 shovers + 2 aux per side) | All six piece types in the distribution |
| `endgame-tactics` | 6, rejection-sampled | Guarantees a hook/throw/charge is available |

The `--fixture` flag accepts a comma-separated cyclic list. The first fixture
is also used for gate positions. Mix sparse endgames with full-board to balance
tactical learning with strategic play.

---

## What we learned: the experiment history

### The sparse-outcome problem (rounds 1–3)

Early full-board games at 100-ply caps produced zero completed games and no
training signal. Raising the cap to 300 plies got games to finish but learning
was slow: all five completed games were won by White, and the network just
learned "predict White wins." Switching to relative encoding (current player's
pieces always face row 0) fixed the color bias.

### The tie-breaking bug

`argmax` systematically favored the engine's first-enumerated legal move.
In one comparison, 298/582 positions had ties for most visits, and the trained
model kept selecting a looping move. Switching to uniform random among tied
maxima was essential for both self-play diversity and fair comparison.

### First confirmed learning: endgame curriculum

Four-piece endgames (one shover + one auxiliary per side, 2–5 rows from goal)
were the first setting where learning demonstrably worked. After three rounds
of 24 games each, the champion scored **36–4** against starting weights on 40
fresh positions (p=0.0000153). The key: positions where games actually end,
giving the value head real signal.

### Broader curriculum stalls

Six-piece and eight-piece endgames produced no second champion. 144 additional
games and 1485 targets failed to pass any gate. The network could win endgame
races but hadn't learned tactical piece interactions. The teacher-headroom
check showed 256 vs 32 simulations scored 29–9 with the same weights — the
search budget mattered more than anything the network had learned.

### Interaction-focused tactics

Rejection-sampling starting positions that guarantee a hook/throw/charge is
available. Three rounds produced no promotion, but surfaced a policy
compression problem: tactical initial decisions were only 3% of replay
despite being the most informative positions. Root-fraction sampling (reserving
half the batch for opening decisions) was added but also didn't produce a
promotion in isolation.

### The local-policy head

The original policy head projects the board to a single 64-dim vector, then
scores all moves against it. Tactical moves (hooks, throws, charges) need
local board context at the specific squares involved. The residual local-policy
head feeds convolutional features at the from/to/actor squares through a small
MLP, adding to the global score. Initialized at zero so it preserves the
existing network exactly.

### Full-board turnaround

The breakthrough came from combining everything: mixed fixtures (2× endgame
for each full-board game), 8 parallel workers, 256-simulation self-play,
proxy draw labels for capped games, and the local-policy head. The pilot
promoted after 256 episodes. Continued training over 70 rounds / 4480 episodes
/ ~12 hours produced **26 champion generations** (18 in the long run alone).

### Final evaluation

The final champion scored **39–0** (1 unfinished) against the original starting
weights on 40 fresh full-board games at equal 256 simulations
(p=0.0000200). Against the pre-long-run champion, the result was inconclusive
(10–11, 18 unfinished) — the 18 gate promotions during training did not each
represent independently confirmed improvements.

### Known limits and open questions

- **Generalization gap**: validation metrics rarely improved even when playing
  strength clearly did. Lower fitting loss ≠ stronger play.
- **Repetition loops**: many unfinished games repeat an 8-ply cycle. The cycle
  guard helps search but doesn't teach the network to avoid them.
- **Value gradient dominance**: at initialization, value gradients were 100×
  larger than policy gradients. Loss balancing (value weight 0.01) helped
  modestly but wasn't decisive.
- **No history in the input**: the network sees the current board, not past
  positions. Repetition detection relies entirely on the engine during search.
  Adding history planes could help the policy avoid known-drawn positions.
- **Depth ceiling**: at 256 simulations, mean maximum search depth is ~4 plies.
  Deeper search (1024 sims) reaches ~5 but costs 4× the time.
- **Comparison with MinMax**: no timed production-player comparison has been
  performed. The 256-simulation fixed-budget protocol is not the same as the
  3-second timed match the production MinMax uses.

### What the network discovered on its own

Without any domain knowledge beyond the rules:
- **Charges**: using chargers to clear paths and capture
- **Hooks**: pulling enemy pieces off their advance line
- **Springboards**: shovers leaping over friendly leapers
- **Endgame technique**: reliably converting material advantages in 4–8 piece positions
- **Opening structure**: learned to develop pieces rather than pushing shovers blindly

The 85K-parameter network running the same method as DeepMind's 44-million-parameter
AlphaZero, 500× smaller, trained on a single laptop CPU in about 12 hours.
