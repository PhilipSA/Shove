import 'dart:math';

import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';

class MinMaxAi extends IPlayer implements IAi {
  MinMaxAi(super.playerName, super.isWhite);
  final stopwatch = Stopwatch();

  @override
  Future<ShoveGameMove> makeMove(ShoveGame game) async {
    stopwatch.start();
    final bestMove =
        minmax(game, this, 20, double.negativeInfinity, double.infinity);
    stopwatch.stop();
    stopwatch.reset();
    return bestMove.$2!;
  }

  (double, ShoveGameMove?) minmax(ShoveGame game, IPlayer maximizingPlayer,
      int depth, double alpha, double beta) {
    if (depth == 0 || game.isGameOver || stopwatch.elapsed.inSeconds > 1) {
      return (
        ShoveGameEvaluator().evaluateGameState(game, maximizingPlayer),
        null
      );
    }

    ShoveGameMove? bestMove;
    var bestScore = maximizingPlayer == game.currentPlayersTurn
        ? double.negativeInfinity
        : double.infinity;

    for (var move in game.getAllLegalMoves()) {
      game.move(move);
      var score = minmax(game, maximizingPlayer, depth - 1, alpha, beta).$1;
      game.undoLastMove();

      if (maximizingPlayer == game.currentPlayersTurn) {
        if (score > bestScore) {
          bestScore = score;
          bestMove = move;
        }
        alpha = max(alpha, score);
      } else {
        if (score < bestScore) {
          bestScore = score;
          bestMove = move;
        }
        beta = min(beta, score);
      }

      if (beta <= alpha) {
        break;
      }
    }

    return (bestScore, bestMove);
  }
}
