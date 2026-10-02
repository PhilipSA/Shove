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

      final cacheKey = game.calculateBoardStateHash();
      final cachedState = stateCalculationCache[cacheKey];

      final double score;
      if (cachedState != null) {
        score = cachedState.$1;
      } else {
        score = (await minmax(
          game,
          maximizingPlayer,
          depth - 1,
          alpha: alpha,
          beta: beta,
          stopwatch: stopwatch,
          stateCalculationCache: stateCalculationCache,
        )).$1;
        stateCalculationCache[cacheKey] = (score, move);
      }

      game.undoLastMove();

      // Always keep some move, even when every option is a forced loss
      bestMove ??= move;

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
      final piece = square.pieceId != null
          ? game.pieces[square.pieceId!]
          : null;
      if (piece == null) continue;

      final sign = piece.owner == maximizingPlayer ? 1.0 : -1.0;
      final opponent = game.getOpponent(piece.owner);

      score += sign * piece.pieceType.pieceValue;

      if (piece.isIncapacitated) {
        score -= sign * 0.5;
      }

      if (piece.pieceType == PieceType.shover) {
        // Shovers closer to the goal are worth more, and much more near the end
        final distance = game.getSquaresDistanceToGoal(piece.owner, square);
        score += sign * (ShoveGame.totalNumberOfRows - distance) * 0.3;
        if (distance <= 2) score += sign * (3 - distance);
      }

      final attackableNeighbors = game.getAllNeighborSquares(square).where((
        element,
      ) {
        final neighbor = game.pieces[element.pieceId];
        return neighbor != null &&
            neighbor.owner == opponent &&
            neighbor.pieceType != PieceType.blocker;
      }).length;

      score +=
          sign *
          switch (piece.pieceType) {
            PieceType.thrower => attackableNeighbors * 1.0,
            PieceType.leaper => attackableNeighbors * 0.5,
            PieceType.shover => attackableNeighbors * 0.5,
            PieceType.blocker => attackableNeighbors * 0.25,
          };
    }

    return score;
  }
}
