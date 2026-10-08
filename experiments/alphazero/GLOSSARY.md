# AlphaZero glossary for Shove

Terms as they appear in this codebase.

## Core concepts

**MCTS (Monte Carlo Tree Search)** — The search algorithm. From the current
position, run many simulated games ("simulations") to build a tree of possible
futures. Each simulation descends the tree by picking the child with the highest
PUCT score, expands one new node, and backs up the result. After all simulations,
pick the move with the most visits. In this codebase: `search()` in `train.py`.

**PUCT** — The formula for balancing exploitation and exploration when choosing
which child to descend into during a simulation:
`score = -child_mean_value + c * prior * sqrt(parent_visits + 1) / (child_visits + 1)`.
Moves the network thinks are good (high prior) get explored early; as visits
accumulate, the mean value dominates. c=1.5 in this codebase.

**PolicyValue network** — A single neural network with two outputs: a **policy**
(which moves look promising) and a **value** (who is winning). The policy guides
MCTS exploration; the value replaces rollouts. `PolicyValue` class in `train.py`.

**Self-play** — The network plays games against itself. Each position is stored
with the MCTS visit distribution (policy target) and the eventual game outcome
(value target). These become the training data. `self_play()` in `train.py`.

**Dirichlet noise** — Random noise mixed into the root prior during self-play
(α=min(1, 10/legal_moves), weight 25%). Forces the search to explore moves the
network currently dislikes, preventing early convergence to a narrow repertoire.
Not used during evaluation or gate matches.

**Champion loop** — The outer training loop (`loop.py`). A "learner" network
trains continuously; periodically it is tested against the current "champion"
in a gate match. If the learner wins enough (≥55%), it becomes the new champion.
Failed learners keep training. 26 champions were promoted during the full run.

**Promotion gate** — A fixed set of color-swapped games at equal simulation
budgets. Both sides get the same search depth. Score ≥55% triggers promotion.
Unfinished games count as draws (0.5). Paired sign-test p-values are reported
but the score threshold is the operational criterion.

**Replay buffer** — An in-memory ring buffer (capacity 4096–60000 positions)
of positions from recent self-play. Training samples mini-batches from this
buffer. Older positions are evicted but their input fingerprints are retained
to check for training/held-out overlap.

## Encoding

**Relative encoding (v2)** — The board is always presented from the current
player's perspective: own pieces advance toward row 0, and the board is flipped
for Black. This prevents the network from learning "White always wins" from
asymmetric data. The policy's square IDs are flipped correspondingly.

**24 input planes** — 6 piece types × 2 owners × 2 stun states. Each plane is
an 8×8 binary grid. No absolute color channel, no history planes.

**Joint-embedding policy** — Instead of a huge fixed-size output (one logit per
possible move), the policy embeds each legal move's from/to/actor squares into
a 24-dim vector, projects the board features to 32-dim, and takes a scaled dot
product. This handles variable legal-move counts naturally.

**Local-policy residual** — An upgrade that adds board-aware features at the
specific squares a move touches: convolutional activations at from/to/actor
positions, plus geometry and actor-valid flag. Adds to the global policy score.
Initialized at zero so the existing network is preserved on upgrade.

## Search details

**Simulations** — The fixed count of MCTS tree expansions per move. Not
milliseconds, not depth, not nodes. 256 simulations ≈ 90–100ms on CPU,
reaching mean max depth ~4 plies.

**Cycle guard** — Simulated positions that would repeat the same board/stuns/side
get a neutral (zero) value instead of further expansion. Prevents MCTS from
infinitely looping, without fabricating terminal states. The Dart engine handles
actual repetition draws.

**Terminal proof** — When any simulation discovers an immediate winning child
(the engine says it's terminal and won), the returned policy concentrates on
discovered winners regardless of visit counts. Same simulation budget, no extra
probes. `policySource: 'terminalProof'` in the output.

**Root value** — The MCTS root's mean backed-up value after all simulations.
From the side-to-move's perspective, in [-1, +1]. This is the search's
assessment of the position.

## Training specifics

**Fixture** — A starting-position generator. `initial` is the standard opening;
`endgame`/`endgame6`/`endgame8` place a few pieces near the goal;
`endgame-tactics` rejection-samples to guarantee a hook/throw/charge is
available. The `--fixture` flag accepts a cyclic list.

**Proxy cap label** — When `--capped-as-draw` is set, games that hit the ply
cap get value targets of 0 (draw). Their actual outcome is recorded as
"unfinished" — the zero label is a training assumption, not an engine ruling.

**Root-fraction sampling** — Reserves a portion of each gradient batch for
opening-position decisions (history length 0), ensuring tactical initial moves
aren't drowned out by mid-game positions from long episodes.

**Value-loss weight** — Scales the value head's gradient during optimization.
At initialization, value gradients are ~100× larger than policy gradients.
Reducing this (e.g. 0.01) prevents the value head from dominating shared
encoder training.

## Dart integration

**Engine bridge** — `engine.dart` runs as a subprocess, communicating via
JSON lines. Python sends `reset`/`observe`/`push`/`pop`/`choose` commands;
Dart runs the actual game rules. No rules are reimplemented in Python.

**weights.json** — The browser-loadable export: all tensor shapes and values
as JSON (~1.8 MB). `dart_network.dart` loads these and reimplements the
forward pass without PyTorch.

**Champion service** — `champion_service.py`: a JSON-lines process that loads
frozen weights and responds to the same protocol as the engine bridge. Used
for integrating with other match runners or worktrees.

**Parity verification** — `verify_dart_runtime.py` checks that the Dart native
player, its JavaScript compilation, and the shipped web worker all produce
identical inference and search results against the Python reference. Maximum
observed errors: logit ~1.5e-6, value ~5.8e-7.
