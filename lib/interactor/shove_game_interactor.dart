import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';

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
  Isolate? _currentEvaluationIsolate;
  bool isEvalbarEnabled = false;

  ShoveGameInteractor(this.shoveGame);

  void dispose() {
    shoveGameEvaluationState.dispose();
    shoveGameMoveState.dispose();
    shoveGameOverState.dispose();
    _currentEvaluationIsolate?.kill();
    _currentEvaluationIsolate = null;
    _isDisposed = true;
  }

  static Future<void> isolatedEvaluateGameState(SendPort sendPort) async {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      final shoveGame = message as ShoveGame;
      final stopwatch = Stopwatch();

      stopwatch.start();
      final evaluationResult = (await const ShoveGameEvaluator().minmax(
              shoveGame, shoveGame.player1, 8,
              stopwatch: stopwatch, stateCalculationCache: HashMap()))
          .$1;
      stopwatch.stop();
      stopwatch.reset();
      sendPort.send(evaluationResult);
    });
  }

  Future<void> evaluateGameStateWeb() async {
    final stopwatch = Stopwatch()..start();

    final evaluationResult = await Future.microtask(() {
      return const ShoveGameEvaluator().minmax(shoveGame, shoveGame.player1, 8,
          stopwatch: stopwatch, stateCalculationCache: HashMap());
    });

    shoveGameEvaluationState.evaluation = evaluationResult.$1;
    stopwatch.stop();
    stopwatch.reset();
  }

  Future<void> evaluateGameState() async {
    if (_currentEvaluationIsolate != null) {
      _currentEvaluationIsolate!.kill(priority: Isolate.immediate);
    }

    final receivePort = ReceivePort();
    _currentEvaluationIsolate = await Isolate.spawn(
        isolatedEvaluateGameState, receivePort.sendPort,
        debugName: 'evaluationIsolate');

    final sendPortAwaiter = Completer<SendPort>();
    receivePort.listen((message) {
      if (message is SendPort) {
        sendPortAwaiter.complete(message);
        return;
      }

      if (_isDisposed) {
        return;
      }
      shoveGameEvaluationState.evaluation = message as double;
      receivePort.close();
      _currentEvaluationIsolate?.kill();
      _currentEvaluationIsolate = null;
    });
    final send2Isolate = await sendPortAwaiter.future;
    send2Isolate.send(shoveGame);
  }

  Future<AssetSource?> onProcceedGameState() async {
    final assetSource = await shoveGame.procceedGameState();

    if (isEvalbarEnabled) {
      if (kIsWeb) {
        await evaluateGameStateWeb();
      } else {
        await evaluateGameState();
      }
    }
    if (assetSource != null) {
      await ShoveAudioPlayer().play(assetSource);
    }
    if (_isDisposed) {
      return null;
    }
    shoveGameMoveState.assetSourceToPlay = assetSource;
    shoveGameOverState.isGameOver = shoveGame.isGameOver;
    return assetSource;
  }

  Future<void> makeMove(ShoveGameMove move) async {
    final audioToPlay = shoveGame.move(move);
    shoveGameMoveState.assetSourceToPlay = audioToPlay;
    if (audioToPlay != null) {
      await ShoveAudioPlayer().play(audioToPlay);
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
