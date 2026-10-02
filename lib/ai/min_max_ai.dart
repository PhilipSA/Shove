import 'dart:convert';

import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_game_move_dto.dart';
import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator_service.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/ai/shove_search.dart';

class MinMaxAi extends IPlayer implements IAi {
  /// How long to think per move; longer means a deeper search and a stronger AI.
  final Duration thinkTime;

  /// Think on a background worker so the UI stays responsive.
  final bool useWorker;

  MinMaxAi(
    super.playerName,
    super.isWhite, {
    this.thinkTime = const Duration(seconds: 3),
    this.useWorker = true,
  });

  @override
  Future<ShoveGameMove> makeMove(ShoveGame game) async {
    if (!useWorker) {
      final result = ShoveSearch(game).findBestMove(timeLimit: thinkTime);
      if (result == null) throw StateError('$playerName has no legal moves');
      return result.move;
    }

    final worker = ShoveGameEvaluatorServiceWorker();
    final String? bestMove;
    try {
      bestMove = await worker.findBestMove(
        jsonEncode(ShoveGameStateDto.fromGame(game).toJson()),
      );
    } finally {
      worker.stop();
    }

    final dto = ShoveGameMoveDto.fromJson(jsonDecode(bestMove!));
    final thrower = dto.throwerSquare;
    return ShoveGameMove(
      game.getSquareByXY(dto.oldSquare.x, dto.oldSquare.y)!,
      game.getSquareByXY(dto.newSquare.x, dto.newSquare.y)!,
      game.currentPlayersTurn,
      throwerSquare: thrower == null
          ? null
          : game.getSquareByXY(thrower.x, thrower.y),
    );
  }
}
