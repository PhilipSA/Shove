// Native/browser-compatible player core. Load weights outside this file.
import 'dart:math';

import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';

import 'dart_network.dart';

List<int> azBoard(ShoveGame game) => [
  for (final square in game.squares)
    if (game.pieceOn(square) case final piece?)
      1 +
          piece.pieceType.index +
          (piece.owner.isWhite ? 0 : 6) +
          (piece.isIncapacitated ? 12 : 0)
    else
      0,
];

List<int> azMove(ShoveGameMove move) => [
  move.oldSquare.x * 8 + move.oldSquare.y,
  move.newSquare.x * 8 + move.newSquare.y,
  move.throwerSquare == null
      ? 64
      : move.throwerSquare!.x * 8 + move.throwerSquare!.y,
];

/// Private search board with history squares bound to that board, like real play.
/// ShoveGame.copy() freezes history squares, which changes repetition equality.
ShoveGame copyAlphaZeroSearchGame(ShoveGame game) {
  final working = game.copy();
  working.allMadeMoves
    ..clear()
    ..addAll(
      game.allMadeMoves.map(
        (move) => ShoveGameMove(
          working.getSquareByXY(move.oldSquare.x, move.oldSquare.y)!,
          working.getSquareByXY(move.newSquare.x, move.newSquare.y)!,
          move.madeBy,
          throwerSquare: move.throwerSquare == null
              ? null
              : working.getSquareByXY(
                  move.throwerSquare!.x,
                  move.throwerSquare!.y,
                ),
        ),
      ),
    );
  return working;
}

String _identity(ShoveGame game) =>
    '${game.currentPlayersTurn.isWhite}:${azBoard(game).join(',')}';

double _terminalValue(ShoveGame game) {
  final winner = game.gameOverState?.winner;
  return winner == null
      ? 0
      : winner == game.currentPlayersTurn
      ? 1
      : -1;
}

class _Node {
  final double prior;
  int visits = 0;
  double total = 0;
  List<ShoveGameMove> moves = [];
  List<_Node> children = [];
  bool immediateWin = false;
  _Node([this.prior = 1]);
  double get mean => visits == 0 ? 0 : total / visits;
}

class AzSearchResult {
  final ShoveGameMove move;
  final List<int> actionVisits;
  final List<int> policyVisits;
  final int simulations;
  final int maxDepth;
  final int cycles;
  final double rootValue;
  final bool provenImmediateWin;
  AzSearchResult(
    this.move,
    this.actionVisits,
    this.policyVisits,
    this.simulations,
    this.maxDepth,
    this.cycles,
    this.rootValue,
    this.provenImmediateWin,
  );
}

class AlphaZeroAi extends IPlayer implements IAi {
  final DartPolicyValue network;
  final int simulations;
  final Duration? thinkTime;
  final bool cycleGuard;
  final double valueScale;
  final Random _random;
  AzSearchResult? lastSearch;

  /// Fixed simulations by default. With thinkTime, simulations is an upper bound;
  /// deadlines are checked between simulations (one simulation may overrun).
  /// Run in a worker before using this synchronous search from a browser UI.
  AlphaZeroAi(
    super.playerName,
    super.isWhite, {
    required this.network,
    this.simulations = 256,
    this.thinkTime,
    this.cycleGuard = true,
    this.valueScale = 1,
    int seed = 1,
  }) : _random = Random(seed) {
    if (simulations < 1 ||
        (thinkTime != null && thinkTime! <= Duration.zero) ||
        !valueScale.isFinite ||
        valueScale < 0 ||
        valueScale > 1) {
      throw ArgumentError('Invalid AlphaZero search budget/value scale');
    }
  }

  double _expand(_Node node, ShoveGame game) {
    if (game.isGameOver) return _terminalValue(game);
    node.moves = game.getAllLegalMoves();
    final prediction = network.predict(
      azBoard(game),
      game.currentPlayersTurn.isWhite ? 0 : 1,
      [for (final move in node.moves) azMove(move)],
    );
    node.children = [for (final prior in prediction.policy) _Node(prior)];
    return prediction.value * valueScale;
  }

  @override
  Future<ShoveGameMove> makeMove(ShoveGame game) async {
    lastSearch = null;
    if (!game.player1.isWhite ||
        game.player2.isWhite ||
        game.currentPlayersTurn.isWhite != isWhite ||
        game.isGameOver) {
      throw StateError(
        'AlphaZero requires its own turn in a nonterminal White/Black game',
      );
    }
    final clock = Stopwatch()..start();
    final working = copyAlphaZeroSearchGame(game); // Caller remains untouched.
    final root = _Node();
    _expand(root, working);
    var completed = 0, maxDepth = 0, cycles = 0;
    while (completed < simulations &&
        (completed == 0 || thinkTime == null || clock.elapsed < thinkTime!)) {
      var node = root;
      final path = [root];
      final seen = {_identity(working)};
      var pushed = 0;
      var repeated = false;
      try {
        while (node.children.isNotEmpty) {
          var index = 0;
          var best = double.negativeInfinity;
          for (var i = 0; i < node.children.length; i++) {
            final child = node.children[i];
            final score =
                -child.mean +
                1.5 * child.prior * sqrt(node.visits + 1) / (child.visits + 1);
            if (score > best) {
              best = score;
              index = i;
            }
          }
          working.move(node.moves[index]);
          pushed++;
          node = node.children[index];
          if (path.length == 1 &&
              working.isGameOver &&
              _terminalValue(working) == -1) {
            node.immediateWin = true;
          }
          path.add(node);
          if (cycleGuard &&
              !working.isGameOver &&
              !seen.add(_identity(working))) {
            repeated = true;
            cycles++;
            break;
          }
        }
        maxDepth = max(maxDepth, pushed);
        var value = repeated ? 0.0 : _expand(node, working);
        for (final ancestor in path.reversed) {
          ancestor.visits++;
          ancestor.total += value;
          value = -value;
        }
        completed++;
      } finally {
        for (var i = 0; i < pushed; i++) {
          working.undoLastMove();
        }
      }
    }
    final wins = root.children.any((node) => node.immediateWin);
    final visits = [for (final node in root.children) node.visits];
    final policyVisits = [
      for (final node in root.children)
        wins && !node.immediateWin ? 0 : node.visits,
    ];
    final maximum = policyVisits.reduce(max);
    final ties = [
      for (var i = 0; i < policyVisits.length; i++)
        if (policyVisits[i] == maximum) i,
    ];
    final index = ties[_random.nextInt(ties.length)];
    // Return a legal move belonging to the original game, not the search copy.
    final wanted = azMove(root.moves[index]);
    final move = game.getAllLegalMoves().firstWhere(
      (move) => azMove(move).join(',') == wanted.join(','),
    );
    lastSearch = AzSearchResult(
      move,
      visits,
      policyVisits,
      completed,
      maxDepth,
      cycles,
      wins ? 1 : root.mean,
      wins,
    );
    return move;
  }
}
