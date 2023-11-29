import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator.dart';
import 'package:shove/game_objects/shove_game.dart';

class ShoveGameEvaluationState extends ChangeNotifier {
  double _evaluation = 0;

  double get evaluation => _evaluation;

  set evaluation(double value) {
    _evaluation = value;
    notifyListeners();
  }
}

class ShoveGameInteractor {
  final ShoveGame shoveGame;

  ShoveGameInteractor(this.shoveGame);

  final shoveGameEvaluationState = ShoveGameEvaluationState();

  static Future<double> isolatedEvaluateGameState(String shoveGameJson) async {
    final shoveGameDto = ShoveGameStateDto.fromJson(jsonDecode(shoveGameJson));
    final shoveGame = ShoveGame.fromDto(shoveGameDto);

    final evaluationResult = (await const ShoveGameEvaluator()
            .minmax(shoveGame, shoveGame.player1, 3))
        .$1;
    return evaluationResult;
  }

  Future<void> evaluateGameState() async {
    final eval = await compute(isolatedEvaluateGameState,
        jsonEncode(ShoveGameStateDto.fromGame(shoveGame)));

    shoveGameEvaluationState.evaluation = eval;
  }

  Future<AssetSource?> onProcceedGameState() async {
    final assetSource = await shoveGame.procceedGameState();
    evaluateGameState();
    return assetSource;
  }
}
