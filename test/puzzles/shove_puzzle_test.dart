import 'package:flutter_test/flutter_test.dart';
import 'package:shove/puzzles/shove_puzzle_session.dart';
import 'package:shove/puzzles/shove_puzzle_solver.dart';
import 'package:shove/puzzles/shove_puzzles.dart';
import 'package:shove/resources/shove_assets.dart';

import '../test_helpers.dart';

ShovePuzzleSession sessionFor(
  int index, {
  void Function(AudioAssets)? onSound,
}) => ShovePuzzleSession(
  shovePuzzles[index],
  onSound: onSound,
  opponentDelay: Duration.zero,
  wrongMoveDelay: Duration.zero,
);

void main() {
  group('puzzle set', () {
    for (final puzzle in shovePuzzles) {
      test(
        '"${puzzle.title}" is won in ${puzzle.movesToWin} with one move',
        () {
          final game = puzzle.buildGame();

          expect(game.isGameOver, isFalse);
          expect(ShovePuzzleSolver.winsWithin(game, puzzle.movesToWin), isTrue);
          expect(
            ShovePuzzleSolver.winsWithin(game, puzzle.movesToWin - 1),
            isFalse,
            reason: 'it can be won faster',
          );
          expect(
            ShovePuzzleSolver.winningMoves(game, puzzle.movesToWin),
            hasLength(1),
            reason: 'it has more than one solution',
          );
        },
      );
    }
  });

  group('session', () {
    test('a winning single move solves the puzzle', () async {
      final session = sessionFor(0);

      await session.makeMove(moveOf(session.game, (2, 5), (0, 5)));

      expect(session.status, PuzzleStatus.solved);
      expect(session.mistakes, 0);
    });

    test('a move that does not win is taken back', () async {
      final session = sessionFor(0);
      final before = session.game.positionKey;

      await session.makeMove(moveOf(session.game, (6, 2), (5, 2)));

      expect(session.status, PuzzleStatus.solving);
      expect(session.mistakes, 1);
      expect(session.game.positionKey, before);
      expect(session.game.allMadeMoves, isEmpty);
    });

    test('the opponent replies and the puzzle goes on', () async {
      final sounds = <AudioAssets>[];
      final session = sessionFor(3, onSound: sounds.add);

      await session.makeMove(moveOf(session.game, (2, 5), (1, 6)));

      expect(session.status, PuzzleStatus.solving);
      expect(session.movesLeft, 1);
      expect(session.game.allMadeMoves, hasLength(2));
      expect(sounds, hasLength(2));

      await session.makeMove(moveOf(session.game, (2, 6), (0, 6)));

      expect(session.status, PuzzleStatus.solved);
    });

    test('moves are ignored while the opponent is replying', () async {
      final session = ShovePuzzleSession(
        shovePuzzles[3],
        opponentDelay: const Duration(milliseconds: 20),
      );
      addTearDown(session.dispose);

      final first = session.makeMove(moveOf(session.game, (2, 5), (1, 6)));
      expect(session.status, PuzzleStatus.opponentReplying);

      await session.makeMove(moveOf(session.game, (2, 6), (0, 6)));
      expect(session.game.allMadeMoves, hasLength(1));

      await first;
      expect(session.game.allMadeMoves, hasLength(2));
    });

    test('hints first show the text, then the piece to move', () {
      final session = sessionFor(3);

      expect(session.hintTextShown, isFalse);
      session.showHint();
      expect(session.hintTextShown, isTrue);
      expect(session.hintSquares, isEmpty);

      session.showHint();
      expect(session.hintSquares, {(2, 5)});
    });

    test('the hint points at the helper when a piece is thrown', () {
      final session = sessionFor(5)
        ..showHint()
        ..showHint();

      expect(session.hintSquares, {(3, 0)});
    });

    test('reset restores the starting position', () async {
      final session = sessionFor(3);
      final start = session.game.positionKey;
      await session.makeMove(moveOf(session.game, (2, 5), (1, 6)));

      session.reset();

      expect(session.game.positionKey, start);
      expect(session.movesLeft, 2);
      expect(session.status, PuzzleStatus.solving);
    });
  });
}
