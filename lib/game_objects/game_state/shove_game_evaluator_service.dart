import 'dart:convert';

import 'package:shove/ai/min_max_ai.dart';
import 'package:shove/game_objects/dto/shove_game_move_dto.dart';
import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator_service.activator.g.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:squadron/squadron.dart';

part 'shove_game_evaluator_service.worker.g.dart';

@SquadronService(
  baseUrl: '~',
  targetPlatform: TargetPlatform.vm | TargetPlatform.js,
)
base class ShoveGameEvaluatorService {
  @squadronMethod
  Future<double> evaluateGameState(
    String shoveGameJson,
    String shovePlayerJson,
  ) async => _evaluateGameState(shoveGameJson, shovePlayerJson);

  @squadronMethod
  Future<String?> findBestMove(String shoveGameJson) async =>
      _findBestMove(shoveGameJson);

  static const _thinkTime = Duration(seconds: 3);

  static Future<String?> _findBestMove(String shoveGameDto) async {
    final shoveGame = ShoveGame.fromDto(
      ShoveGameStateDto.fromJson(jsonDecode(shoveGameDto)),
    );
    final player = shoveGame.currentPlayersTurn;
    // Already inside the worker, so think right here
    final ai = MinMaxAi(
      player.playerName,
      player.isWhite,
      thinkTime: _thinkTime,
      useWorker: false,
    );
    final move = await ai.makeMove(shoveGame);

    return jsonEncode(ShoveGameMoveDto.fromGameMove(move).toJson());
  }

  // Evaluation bar is disabled for now: the search is private to MinMaxAi.
  static Future<double> _evaluateGameState(
    String shoveGameDto,
    String shovePlayerDto,
  ) async => 0;
}
