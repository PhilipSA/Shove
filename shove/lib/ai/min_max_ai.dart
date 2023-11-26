import 'dart:math';

import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';

class MinMaxAi extends IPlayer implements IAi {
  MinMaxAi(super.playerName, super.isWhite);
  final stopwatch = Stopwatch();

  @override
  Future<ShoveGameMove> makeMove(ShoveGame game) async {
    stopwatch.start();
    final bestMove =
        minmax(game, this, 10, double.negativeInfinity, double.infinity);
    stopwatch.stop();
    stopwatch.reset();
    return bestMove.$2!;
  }

  (double, ShoveGameMove?) minmax(ShoveGame game, IPlayer maximizingPlayer,
      int depth, double alpha, double beta) {
    if (depth == 0 || game.isGameOver || stopwatch.elapsed.inSeconds > 1) {
      return (evaluateGameState(game, maximizingPlayer), null);
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

  double evaluateGameState(ShoveGame game, IPlayer maximizingPlayer) {
    var score = 0.0;

    if (game.isGameOver) {
      if (game.winner == maximizingPlayer) {
        score += double.infinity;
      } else {
        score += double.negativeInfinity;
      }
    }

    for (final square in game.board.expand((i) => i).toList()) {
      final isMaximizingPlayersPiece =
          square.piece?.owner == maximizingPlayer && square.piece != null;
      final isOpponentsPiece =
          square.piece?.owner != maximizingPlayer && square.piece != null;
      final pieceIsThrower = square.piece?.pieceType == PieceType.thrower;
      final pieceIsShover = square.piece?.pieceType == PieceType.shover;

      if (isMaximizingPlayersPiece) {
        score += square.piece?.pieceType.pieceValue ?? 0;
      } else if (isOpponentsPiece) {
        score -= square.piece?.pieceType.pieceValue ?? 0;
      }

      if (square.piece?.isIncapacitated == true) {
        score += isMaximizingPlayersPiece ? -0.5 : 0.5;
      }

      if (pieceIsThrower) {
        final countThrowableNeighbors = game
            .getAllNeighborSquares(square)
            .where((element) =>
                element.piece != null &&
                element.piece?.owner ==
                    game.getOpponent(element.piece!.owner) &&
                element.piece?.pieceType != PieceType.blocker)
            .length;

        score += isMaximizingPlayersPiece
            ? countThrowableNeighbors
            : -countThrowableNeighbors;
      }

      if (square.piece?.pieceType == PieceType.blocker) {
        final countBlockableNeighbors = game
            .getAllNeighborSquares(square)
            .where((element) =>
                element.piece != null &&
                element.piece?.owner ==
                    game.getOpponent(element.piece!.owner) &&
                element.piece?.pieceType != PieceType.blocker)
            .length;

        score += isMaximizingPlayersPiece
            ? countBlockableNeighbors
            : -countBlockableNeighbors;
      }

      if (pieceIsShover) {
        final countShoveableNeighbors = game
            .getAllNeighborSquares(square)
            .where((element) =>
                element.piece != null &&
                element.piece?.owner ==
                    game.getOpponent(element.piece!.owner) &&
                element.piece?.pieceType != PieceType.blocker)
            .length;

        score += isMaximizingPlayersPiece
            ? countShoveableNeighbors
            : -countShoveableNeighbors;
      }
    }

    return score;
  }
}
