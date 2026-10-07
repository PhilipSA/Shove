// Messages between AlphaZeroAi and its worker. The worker never sees the caller's
// ShoveGame: it replays the actual move list on a fresh standard game, so history
// (repetitions, stuns, undo information) is exact and nothing is shared.
import 'dart:math';

import 'package:shove/ai/alpha_zero/alpha_zero_ai.dart';
import 'package:shove/ai/alpha_zero/az_network.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_player.dart';

/// A search request for the player to move in [game]: every made move as
/// `[from, to, actor]` (actor 64 when absent) plus the position they must lead to.
Map<String, Object?> alphaZeroRequest(
  ShoveGame game, {
  required Duration thinkTime,
  required int simulations,
  required int seed,
}) => {
  'white': game.player1.playerName,
  'black': game.player2.playerName,
  'moves': [for (final move in game.allMadeMoves) azMove(move)],
  'board': azBoard(game),
  'turn': game.currentPlayersTurn.isWhite ? 0 : 1,
  'thinkMs': thinkTime.inMilliseconds,
  'simulations': simulations,
  'seed': seed,
};

/// Plays the request's moves from the standard start, matching each against the
/// legal moves, and checks the final board, stuns and turn against the caller's.
/// Throws a [FormatException] for histories it cannot reproduce, e.g. custom starts.
ShoveGame replayAlphaZeroHistory(Map<String, dynamic> request) {
  final game = ShoveGame(
    ShovePlayer(request['white'] as String, true),
    ShovePlayer(request['black'] as String, false),
  );
  final moves = request['moves'] as List;
  for (var i = 0; i < moves.length; i++) {
    final wanted = (moves[i] as List).join(',');
    if (game.isGameOver) {
      throw FormatException('The game was already over before move ${i + 1}.');
    }
    final legal = game.getAllLegalMoves().where(
      (move) => azMove(move).join(',') == wanted,
    );
    if (legal.isEmpty) {
      throw FormatException(
        'Move ${i + 1} ($wanted) is not legal from the standard start; '
        'AlphaZero does not support custom starting positions.',
      );
    }
    game.move(legal.first);
  }
  final board = request['board'] as List;
  if (game.isGameOver ||
      (game.currentPlayersTurn.isWhite ? 0 : 1) != request['turn'] ||
      azBoard(game).join(',') != board.join(',')) {
    throw const FormatException(
      'The replayed game differs from the board; AlphaZero does not support '
      'custom starting positions.',
    );
  }
  return game;
}

/// Answers a request: replay, then a search bounded by the same think time
/// (the replay counts against it). Returns the chosen move tuple and search stats.
Future<Map<String, Object?>> runAlphaZeroRequest(
  DartPolicyValue network,
  Map<String, dynamic> request,
) async {
  final clock = Stopwatch()..start();
  final game = replayAlphaZeroHistory(request);
  final remaining = (request['thinkMs'] as int) - clock.elapsedMilliseconds;
  final ai = AlphaZeroAi(
    game.currentPlayersTurn.playerName,
    game.currentPlayersTurn.isWhite,
    network: network,
    simulations: request['simulations'] as int,
    thinkTime: Duration(milliseconds: max(1, remaining)),
    seed: request['seed'] as int,
  );
  final move = await ai.makeMove(game);
  final search = ai.lastSearch!;
  return {
    'move': azMove(move),
    'simulations': search.simulations,
    'maxDepth': search.maxDepth,
    'cycles': search.cycles,
    'rootValue': search.rootValue,
    'provenImmediateWin': search.provenImmediateWin,
    'elapsedMs': clock.elapsedMilliseconds,
  };
}
