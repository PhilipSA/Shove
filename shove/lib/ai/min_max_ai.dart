
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';

class MinMaxAi extends IPlayer implements IAi {
  MinMaxAi(super.playerName, super.isWhite);

  @override
  Future<ShoveGameMove> makeMove(ShoveGame game) async {
    return minmax(game, 3).$2!;
  }

  // MinMax algorithm implementation
  (double, ShoveGameMove?) minmax(ShoveGame game, int depth) {
    if (depth == 0 || game.isGameOver) {
      return (
        evaluateGameState(game),
        null
      ); // Replace with your evaluation function
    }

    ShoveGameMove? bestMove;
    var bestScore = isWhite ? double.negativeInfinity : double.infinity;

    for (var move in game.getAllLegalMoves()) {
      // Apply move
      game.move(move);

      // Recursively call minmax
      var score = minmax(game, depth - 1).$1;

      // Undo move
      game.undoLastMove();

      if ((isWhite && score > bestScore) || (!isWhite && score < bestScore)) {
        bestScore = score;
        bestMove = move;
      }
    }

    return (bestScore, bestMove);
  }

  // Evaluate the game state and return a score
  // Current player want to maximize the score
  double evaluateGameState(ShoveGame game) {
    final currentPlayersRemainingPieces = game.pieces
        .where((element) => element.owner == game.currentPlayersTurn)
        .length
        .toDouble();

    final otherPlayersRemainingPieces = game.pieces
        .where((element) => element.owner != game.currentPlayersTurn)
        .length
        .toDouble();

    return currentPlayersRemainingPieces - otherPlayersRemainingPieces;
  }
}
