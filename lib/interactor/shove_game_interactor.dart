import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
import 'package:shove/game_objects/dto/shove_player_dto.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator_service.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_move_notation.dart';
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

/// Notifies whenever the board changes (move, undo) or the AI starts/stops thinking.
class ShoveGameMoveState extends ChangeNotifier {
  bool _isAiThinking = false;

  bool get isAiThinking => _isAiThinking;

  set isAiThinking(bool value) {
    _isAiThinking = value;
    notifyListeners();
  }

  void notifyBoardChanged() => notifyListeners();
}

class ShoveGameOverState extends ChangeNotifier {
  bool _isGameOver = false;
  IPlayer? _winner;
  GameOverReason? _reason;

  bool get isGameOver => _isGameOver;
  IPlayer? get winner => _winner;
  GameOverReason? get reason => _reason;
  bool get isDraw => _isGameOver && _winner == null;

  void update(ShoveGame game) {
    _isGameOver = game.isGameOver;
    _winner = game.gameOverState?.winner;
    _reason = game.gameOverReason;
    notifyListeners();
  }
}

class ShoveGameInteractor {
  final ShoveGame shoveGame;
  final ShoveAudioPlayerFactory createAudioPlayer;
  final shoveGameEvaluationState = ShoveGameEvaluationState();
  final shoveGameMoveState = ShoveGameMoveState();
  final shoveGameOverState = ShoveGameOverState();
  bool _isDisposed = false;
  bool isEvalbarEnabled = false;

  final int _movesBeforeStart;
  // _positions[i] is the board after i moves (0 = start); _records[i - 1] describes move i.
  final List<ShoveGame> _positions;
  final List<ShoveMoveRecord> _records = [];
  int? _viewedPly;

  ShoveGameInteractor(
    this.shoveGame, {
    this.createAudioPlayer = ShoveAudioPlayer.new,
  }) : _movesBeforeStart = shoveGame.allMadeMoves.length,
       _positions = [shoveGame.snapshot()];

  List<ShoveMoveRecord> get moveRecords => UnmodifiableListView(_records);

  bool get isViewingHistory => _viewedPly != null;

  /// Number of the move shown (0 = start position).
  int get shownPly => _viewedPly ?? _records.length;

  /// The board to display: the live game, or a past position when viewing history.
  ShoveGame get displayedGame =>
      _viewedPly == null ? shoveGame : _positions[_viewedPly!];

  void viewMove(int ply) {
    _viewedPly = ply >= _records.length ? null : max(0, ply);
    shoveGameMoveState.notifyBoardChanged();
  }

  bool get isHumansTurn =>
      !isViewingHistory &&
      !shoveGame.isGameOver &&
      shoveGame.currentPlayersTurn is! IAi &&
      !shoveGameMoveState.isAiThinking;

  bool get canUndo =>
      !shoveGameMoveState.isAiThinking &&
      shoveGame.allMadeMoves.any((move) => move.madeBy is! IAi);

  void dispose() {
    _isDisposed = true;
    shoveGameEvaluationState.dispose();
    shoveGameMoveState.dispose();
    shoveGameOverState.dispose();
  }

  Future<void> evaluateGameState() async {
    final worker = ShoveGameEvaluatorServiceWorker();
    final double evaluationResult;
    try {
      evaluationResult = await worker.evaluateGameState(
        jsonEncode(ShoveGameStateDto.fromGame(shoveGame).toJson()),
        jsonEncode(ShovePlayerDto.fromPlayer(shoveGame.player1).toJson()),
      );
    } finally {
      worker.stop();
    }

    if (_isDisposed) return;
    shoveGameEvaluationState.evaluation = evaluationResult;
  }

  void _syncHistory() {
    final plies = max(0, shoveGame.allMadeMoves.length - _movesBeforeStart);
    while (_records.length > plies) {
      _records.removeLast();
      _positions.removeLast();
    }
    if (_records.length < plies) {
      _records.add(ShoveMoveRecord.of(shoveGame, shoveGame.allMadeMoves.last));
      _positions.add(shoveGame.snapshot());
    }
    final viewed = _viewedPly;
    if (viewed != null && viewed >= _records.length) _viewedPly = null;
  }

  void _onBoardChanged(AudioAssets? audio) {
    _syncHistory();
    shoveGameMoveState.notifyBoardChanged();
    shoveGameOverState.update(shoveGame);
    if (audio != null) {
      unawaited(createAudioPlayer().play(AssetSource(audio.assetPath)));
    }
  }

  Future<void> makeMove(ShoveGameMove move) async {
    if (!isHumansTurn || !shoveGame.validateMove(move)) return;

    _onBoardChanged(shoveGame.move(move));
    if (isEvalbarEnabled) unawaited(evaluateGameState());

    await processAiTurns();
  }

  /// Lets the AI play for as long as it is an AI's turn.
  Future<void> processAiTurns() async {
    while (!_isDisposed &&
        !shoveGame.isGameOver &&
        shoveGame.currentPlayersTurn is IAi) {
      shoveGameMoveState.isAiThinking = true;
      final audio = await shoveGame.procceedGameState();
      if (_isDisposed) return;
      shoveGameMoveState.isAiThinking = false;

      _onBoardChanged(audio);
      if (isEvalbarEnabled) await evaluateGameState();
      // Give the UI a moment between consecutive AI moves
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  /// Undoes moves back to (and including) the last move made by a human.
  void undo() {
    if (!canUndo) return;

    _viewedPly = null;
    while (shoveGame.allMadeMoves.isNotEmpty) {
      final last = shoveGame.allMadeMoves.last;
      shoveGame.undoLastMove();
      if (last.madeBy is! IAi) break;
    }
    _onBoardChanged(null);
  }
}
