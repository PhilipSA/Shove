import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shove/audio/shove_audio_player.dart';
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

class ShoveGameMoveState extends ChangeNotifier {
  AssetSource? _assetSourceToPlay;

  AssetSource? get assetSourceToPlay => _assetSourceToPlay;

  set assetSourceToPlay(AssetSource? value) {
    _assetSourceToPlay = value;
    notifyListeners();
  }
}

class ShoveGameInteractor {
  final ShoveGame shoveGame;
  final shoveGameEvaluationState = ShoveGameEvaluationState();
  final shoveGameMoveState = ShoveGameMoveState();
  bool _isDisposed = false;

  ShoveGameInteractor(this.shoveGame);

  void dispose() {
    shoveGameEvaluationState.dispose();
    shoveGameMoveState.dispose();
    _isDisposed = true;
  }

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
    shoveGameMoveState.assetSourceToPlay = assetSource;
    return assetSource;
  }

  Future<void> processAiGame() async {
    if (shoveGame.isGameOver) return;

    final audioToPlay = await onProcceedGameState();

    if (_isDisposed) return;

    if (audioToPlay != null) {
      await ShoveAudioPlayer().play(audioToPlay);
    }

    if (!shoveGame.isGameOver) {
      await Future.delayed(Duration.zero, () async => await processAiGame());
    }
  }
}
