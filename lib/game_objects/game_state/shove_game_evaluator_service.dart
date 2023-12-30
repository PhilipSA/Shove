import 'dart:collection';
import 'dart:convert';

import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
import 'package:shove/game_objects/dto/shove_player_dto.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator_service.activator.g.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
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
  Future<(double, ShoveGameMove?)> findBestMove(String shoveGameJson) async =>
      _findBestMove(shoveGameJson);

  // naive & inefficient implementation of the Fibonacci sequence
  static Future<(double, ShoveGameMove?)> _findBestMove(String shoveGameDto) {
    final shoveGame =
        ShoveGame.fromDto(ShoveGameStateDto.fromJson(jsonDecode(shoveGameDto)));
    final stopwatch = Stopwatch()..start();
    final bestMove = const ShoveGameEvaluator().minmax(
        shoveGame, shoveGame.currentPlayersTurn, 20,
        stopwatch: stopwatch, stateCalculationCache: HashMap());
    stopwatch.stop();
    return bestMove;
  }

  static double _evaluateGameState(String shoveGameDto, String shovePlayerDto) {
    final shoveGame =
        ShoveGame.fromDto(ShoveGameStateDto.fromJson(jsonDecode(shoveGameDto)));
    return const ShoveGameEvaluator().evaluateGameState(
        shoveGame, ShovePlayerDto.fromJson(jsonDecode(shovePlayerDto)));
  }
}
