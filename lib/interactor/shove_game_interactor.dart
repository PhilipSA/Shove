import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
import 'package:shove/game_objects/dto/shove_player_dto.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator_service.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/resources/shove_assets.dart';

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

class ShoveGameOverState extends ChangeNotifier {
  bool _isGameOver = false;

  bool get isGameOver => _isGameOver;

  set isGameOver(bool value) {
    _isGameOver = value;
    notifyListeners();
  }
}

class ShoveGameInteractor {
  final ShoveGame shoveGame;
  final shoveGameEvaluationState = ShoveGameEvaluationState();
  final shoveGameMoveState = ShoveGameMoveState();
  final shoveGameOverState = ShoveGameOverState();
  bool _isDisposed = false;
  bool isEvalbarEnabled = false;

  ShoveGameInteractor(this.shoveGame);

  void dispose() {
    shoveGameEvaluationState.dispose();

    shoveGameMoveState.dispose();
    shoveGameOverState.dispose();
    _isDisposed = true;
  }

  Future<void> evaluateGameState() async {
    final worker = ShoveGameEvaluatorServiceWorker();
    final evaluationResult = await worker.evaluateGameState(
        jsonEncode(ShoveGameStateDto.fromGame(shoveGame).toJson()),
        jsonEncode(
            ShovePlayerDto.fromPlayer(shoveGame.currentPlayersTurn).toJson()));

    worker.stop();
    shoveGameEvaluationState.evaluation = evaluationResult;
  }

  Future<AudioAssets?> onProcceedGameState() async {
    final audioAsset = await shoveGame.procceedGameState();

    if (isEvalbarEnabled) {
      await evaluateGameState();
    }
    if (audioAsset != null) {
      await ShoveAudioPlayer().play(AssetSource(audioAsset.assetPath));
    }
    if (_isDisposed) {
      return null;
    }

    if (audioAsset != null) {
      shoveGameMoveState.assetSourceToPlay = AssetSource(audioAsset.assetPath);
    }
    shoveGameOverState.isGameOver = shoveGame.isGameOver;
    return audioAsset;
  }

  Future<void> makeMove(ShoveGameMove move) async {
    final audioToPlay = shoveGame.move(move);
    if (audioToPlay != null) {
      shoveGameMoveState.assetSourceToPlay = AssetSource(audioToPlay.assetPath);
      await ShoveAudioPlayer().play(AssetSource(audioToPlay.assetPath));
    }

    await onProcceedGameState();
  }

  Future<void> processAiGame() async {
    if (shoveGame.isGameOver) return;

    await onProcceedGameState();

    if (_isDisposed) return;

    if (!shoveGame.isGameOver) {
      await Future.delayed(Duration.zero, () async => await processAiGame());
    }
  }
}
