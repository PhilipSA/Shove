import 'package:flutter/foundation.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/puzzles/shove_puzzle.dart';
import 'package:shove/puzzles/shove_puzzle_solver.dart';
import 'package:shove/resources/shove_assets.dart';

enum PuzzleStatus { solving, opponentReplying, wrongMove, solved }

/// Plays one puzzle: checks every move against the solver and answers for the opponent.
class ShovePuzzleSession extends ChangeNotifier {
  final ShovePuzzle puzzle;
  final void Function(AudioAssets sound)? onSound;
  final Duration opponentDelay;
  final Duration wrongMoveDelay;

  late ShoveGame _game;
  var _status = PuzzleStatus.solving;
  var _movesLeft = 0;
  var _mistakes = 0;
  var _hintTextShown = false;
  Set<(int, int)> _hintSquares = const {};

  // Changes on reset, so a reply that is still pending does not touch the new game
  var _epoch = 0;
  var _isDisposed = false;

  ShovePuzzleSession(
    this.puzzle, {
    this.onSound,
    this.opponentDelay = const Duration(milliseconds: 600),
    this.wrongMoveDelay = const Duration(milliseconds: 1000),
  }) {
    _start();
  }

  ShoveGame get game => _game;
  PuzzleStatus get status => _status;

  /// Moves you still have to win, counting the next one.
  int get movesLeft => _movesLeft;
  int get mistakes => _mistakes;
  bool get isPlayersTurn => _status == PuzzleStatus.solving;
  bool get hintTextShown => _hintTextShown;

  /// Square of the piece to move, once the hint has been asked for twice.
  Set<(int, int)> get hintSquares => _hintSquares;

  void _start() {
    _game = puzzle.buildGame();
    _status = PuzzleStatus.solving;
    _movesLeft = puzzle.movesToWin;
    _mistakes = 0;
    _hintTextShown = false;
    _hintSquares = const {};
  }

  void reset() {
    _epoch++;
    _start();
    notifyListeners();
  }

  /// First reveals the puzzle's hint, then the piece to move.
  void showHint() {
    if (!isPlayersTurn) return;
    if (!_hintTextShown) {
      _hintTextShown = true;
    } else {
      final move = ShovePuzzleSolver.winningMove(_game, _movesLeft);
      if (move == null) return;
      final piece = move.throwerSquare ?? move.oldSquare;
      _hintSquares = {(piece.x, piece.y)};
    }
    notifyListeners();
  }

  Future<void> makeMove(ShoveGameMove move) async {
    if (!isPlayersTurn || !_game.validateMove(move)) return;

    final epoch = _epoch;
    _hintSquares = const {};
    _play(_game.move(move));

    final movesAfter = _movesLeft - 1;
    if (!ShovePuzzleSolver.stillWinsAfterMove(_game, movesAfter)) {
      _mistakes++;
      _status = PuzzleStatus.wrongMove;
      notifyListeners();
      await Future<void>.delayed(wrongMoveDelay);
      if (_isDisposed || epoch != _epoch) return;
      _game.undoLastMove();
      _status = PuzzleStatus.solving;
      notifyListeners();
      return;
    }

    _movesLeft = movesAfter;
    if (_game.isGameOver) {
      _status = PuzzleStatus.solved;
      notifyListeners();
      return;
    }

    _status = PuzzleStatus.opponentReplying;
    notifyListeners();
    await Future<void>.delayed(opponentDelay);
    if (_isDisposed || epoch != _epoch) return;

    final reply = ShovePuzzleSolver.bestDefense(_game, _movesLeft);
    if (reply != null) _play(_game.move(reply));
    _status = _game.isGameOver ? PuzzleStatus.solved : PuzzleStatus.solving;
    notifyListeners();
  }

  void _play(AudioAssets? sound) {
    if (sound != null) onSound?.call(sound);
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
