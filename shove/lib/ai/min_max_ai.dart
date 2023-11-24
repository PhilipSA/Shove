import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';

class MinMaxAi extends IPlayer implements IAi {
  MinMaxAi(super.playerName, super.isWhite);
  final stopwatch = Stopwatch();

  @override
  Future<ShoveGameMove> makeMove(ShoveGame game) async {
    stopwatch.start();
    final bestMove = minmax(game, game.currentPlayersTurn, 5000);
    stopwatch.stop();
    stopwatch.reset();
    return bestMove.$2!;
  }

  (double, ShoveGameMove?) minmax(
      ShoveGame game, IPlayer maximizingPlayer, int depth) {
    if (depth == 0 || game.isGameOver || stopwatch.elapsed.inSeconds > 1) {
      return (
        evaluateGameState(game, maximizingPlayer),
        null
      ); // Replace with your evaluation function
    }

    final isMaximizingPlayersTurn = game.currentPlayersTurn == maximizingPlayer;
    ShoveGameMove? bestMove;
    var bestScore =
        isMaximizingPlayersTurn ? double.negativeInfinity : double.infinity;

    for (var move in game.getAllLegalMoves()) {
      // Apply move
      game.move(move);

      // Recursively call minmax
      var score = minmax(game, maximizingPlayer, depth - 1).$1;

      // Undo move
      game.undoLastMove();

      if ((isMaximizingPlayersTurn && score > bestScore) ||
          (!isMaximizingPlayersTurn && score < bestScore)) {
        bestScore = score;
        bestMove = move;
      }
    }

    return (bestScore, bestMove);
  }

  // Evaluate the game state and return a score
  // Current player want to maximize the score
  double evaluateGameState(ShoveGame game, IPlayer maximizingPlayer) {
    final maxmizingPlayersRemainingPieces = game.pieces
        .where((element) => element.owner == maximizingPlayer)
        .length
        .toDouble();

    final otherPlayersRemainingPieces = game.pieces
        .where((element) => element.owner != maximizingPlayer)
        .length
        .toDouble();

    return maxmizingPlayersRemainingPieces - otherPlayersRemainingPieces;
  }
}
