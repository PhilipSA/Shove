import 'dart:collection';
import 'dart:math';

import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';

class ShoveGameEvaluator {
  const ShoveGameEvaluator();

  Future<(double, ShoveGameMove?)> minmax(
    ShoveGame game,
    IPlayer maximizingPlayer,
    int depth, {
    double alpha = double.negativeInfinity,
    double beta = double.infinity,
    Stopwatch? stopwatch,
    required HashMap<int, (double, ShoveGameMove?)> stateCalculationCache,
  }) async {
    if (depth == 0 ||
        game.isGameOver ||
        (stopwatch?.elapsed.inSeconds ?? 0) > 1) {
      return (evaluateGameState(game, maximizingPlayer), null);
    }

    ShoveGameMove? bestMove;
    var bestScore = maximizingPlayer == game.currentPlayersTurn
        ? double.negativeInfinity
        : double.infinity;

    for (final move in game.getAllLegalMoves()) {
      game.move(move);

      var score = (await minmax(game, maximizingPlayer, depth - 1,
              alpha: alpha,
              beta: beta,
              stopwatch: stopwatch,
              stateCalculationCache: stateCalculationCache))
          .$1;

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
      if (game.gameOverState?.winner == maximizingPlayer) {
        score += double.infinity;
      } else {
        score += double.negativeInfinity;
      }
      if (game.gameOverState?.winner == null) {
        score = -500;
      }
    }

    for (final square in game.board.values) {
      final squareHasPiece = square.piece != null;
      final isMaximizingPlayersPiece =
          square.piece?.owner == maximizingPlayer && square.piece != null;
      final isOpponentsPiece =
          square.piece?.owner != maximizingPlayer && square.piece != null;
      final pieceIsThrower = square.piece?.pieceType == PieceType.thrower;
      final pieceIsShover = square.piece?.pieceType == PieceType.shover;
      final pieceIsLeaper = square.piece?.pieceType == PieceType.leaper;

      if (squareHasPiece && !pieceIsLeaper) {
        final pieceDistancetoOpponentGoal =
            game.getSquaresDistanceToGoal(square.piece!.owner, square) / 10;

        score -= isMaximizingPlayersPiece
            ? pieceDistancetoOpponentGoal
            : -pieceDistancetoOpponentGoal;
      }

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
            ? countThrowableNeighbors * 2
            : -countThrowableNeighbors * 2;
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
