import 'dart:convert';

import 'package:shove/ai/min_max_ai.dart';
import 'package:shove/ai/shove_search.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_game_move_dto.dart';
import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
import 'package:shove/game_objects/dto/shove_player_dto.dart';
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
  static const _evaluationTime = Duration(milliseconds: 500);

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

  /// Evaluation for [shovePlayerDto] in roughly "shovers ahead", clamped to ±10.
  static Future<double> _evaluateGameState(
    String shoveGameDto,
    String shovePlayerDto,
  ) async {
    final shoveGame = ShoveGame.fromDto(
      ShoveGameStateDto.fromJson(jsonDecode(shoveGameDto)),
    );
    final player = IPlayer.fromDto(
      ShovePlayerDto.fromJson(jsonDecode(shovePlayerDto)),
    );

    final result = ShoveSearch(shoveGame)
        .findBestMove(timeLimit: _evaluationTime);
    if (result == null) return 0;
    final sideToMoveIsPlayer = shoveGame.currentPlayersTurn == player;
    final score = (sideToMoveIsPlayer ? result.score : -result.score) / 100;

    return score.clamp(-10.0, 10.0);
  }
}
