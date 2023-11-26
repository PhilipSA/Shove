import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_game.dart';

class ShoveGameEvaluator {
  const ShoveGameEvaluator();

  double evaluateGameState(ShoveGame game, IPlayer maximizingPlayer) {
    var score = 0.0;

    if (game.isGameOver) {
      if (game.gameOverState?.winner == maximizingPlayer) {
        score += double.infinity;
      } else {
        score += double.negativeInfinity;
      }
      if (game.gameOverState?.winner == null) {
        score -= 50;
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

        final pieceDistancetoOpponentGoal =
            game.getSquaresDistanceToGoal(square.piece!.owner, square);

        score -= isMaximizingPlayersPiece
            ? pieceDistancetoOpponentGoal
            : -pieceDistancetoOpponentGoal;
      }
    }

    return score;
  }
}
