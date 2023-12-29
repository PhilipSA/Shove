import 'dart:collection';

import 'package:shove/game_objects/abstraction/i_player.dart';
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
  Future<double> evaluateGameState(ShoveGame shoveGame) async =>
      _evaluateGameState(shoveGame);

  @SquadronMethod()
  Future<(double, ShoveGameMove?)> findBestMove(
          ShoveGame shoveGame, Stopwatch stopwatch, IPlayer player) async =>
      _findBestMove(shoveGame, stopwatch, player);

  // naive & inefficient implementation of the Fibonacci sequence
  static Future<(double, ShoveGameMove?)> _findBestMove(
          ShoveGame shoveGame, Stopwatch stopwatch, IPlayer player) =>
      const ShoveGameEvaluator().minmax(shoveGame, player, 20,
          stopwatch: stopwatch, stateCalculationCache: HashMap());

  // naive & inefficient implementation of the Fibonacci sequence
  static double _evaluateGameState(ShoveGame shoveGame) =>
      const ShoveGameEvaluator()
          .evaluateGameState(shoveGame, shoveGame.currentPlayersTurn);
}
