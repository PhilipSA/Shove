import 'dart:collection';
import 'dart:convert';

import 'package:shove/game_objects/dto/shove_game_move_dto.dart';
import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
import 'package:shove/game_objects/dto/shove_player_dto.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator_service.activator.g.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:squadron/squadron.dart';
import 'package:squadron/squadron_annotations.dart';

part 'shove_game_evaluator_service.worker.g.dart';

@SquadronService()
class ShoveGameEvaluatorService {
  @SquadronMethod()
  Future<double> evaluateGameState(
          String shoveGameJson, String shovePlayerJson) async =>
      _evaluateGameState(shoveGameJson, shovePlayerJson);

  @SquadronMethod()
  Future<String?> findBestMove(String shoveGameJson) async =>
      _findBestMove(shoveGameJson);

  static Future<String?> _findBestMove(String shoveGameDto) async {
    final shoveGame =
        ShoveGame.fromDto(ShoveGameStateDto.fromJson(jsonDecode(shoveGameDto)));
    final stopwatch = Stopwatch()..start();
    final bestMove = await const ShoveGameEvaluator().minmax(
        shoveGame, shoveGame.currentPlayersTurn, 20,
        stopwatch: stopwatch, stateCalculationCache: HashMap());
    stopwatch.stop();

    if (bestMove.$2 == null) return null;

    return jsonEncode(ShoveGameMoveDto.fromGameMove(bestMove.$2!).toJson());
  }

  static Future<double> _evaluateGameState(
      String shoveGameDto, String shovePlayerDto) async {
    final shoveGame =
        ShoveGame.fromDto(ShoveGameStateDto.fromJson(jsonDecode(shoveGameDto)));
    final shovePlayer = ShovePlayerDto.fromJson(jsonDecode(shovePlayerDto));

    final stopwatch = Stopwatch()..start();
    final currentEval = await const ShoveGameEvaluator().minmax(
        shoveGame, shovePlayer, 20,
        stopwatch: stopwatch, stateCalculationCache: HashMap());
    stopwatch.stop();

    return currentEval.$1;
  }
}
