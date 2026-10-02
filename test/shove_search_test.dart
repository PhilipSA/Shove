import 'package:flutter_test/flutter_test.dart';
import 'package:shove/ai/shove_search.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_player.dart';

import 'test_helpers.dart';

final white = ShovePlayer('white', true);
final black = ShovePlayer('black', false);

const quick = Duration(milliseconds: 300);

void main() {
  test('returns null when the side to move has no legal moves', () {
    final game = emptyGame(white, black);
    place(game, 6, 0, ShovePiece.shover(white));
    place(game, 1, 5, ShovePiece.shover(black)).isIncapacitated = true;
    game.currentPlayersTurn = black;

    expect(ShoveSearch(game).findBestMove(timeLimit: quick), isNull);
  });

  test('finds a win in one and reports it as a win', () {
    final game = emptyGame(white, black);
    place(game, 1, 3, ShovePiece.shover(white));
    place(game, 6, 6, ShovePiece.shover(black));

    final result = ShoveSearch(game).findBestMove(timeLimit: quick)!;

    expect((result.move.newSquare.x, result.move.newSquare.y), (0, 3));
    expect(result.isWinFound, isTrue);
    expect(result.isLossFound, isFalse);
  });

  test('returned move uses the squares of the game passed in', () {
    final game = ShoveGame(white, black);

    final move = ShoveSearch(game).findBestMove(timeLimit: quick)!.move;

    expect(
      identical(
        move.oldSquare,
        game.getSquareByXY(move.oldSquare.x, move.oldSquare.y),
      ),
      isTrue,
    );
    expect(
      identical(
        move.newSquare,
        game.getSquareByXY(move.newSquare.x, move.newSquare.y),
      ),
      isTrue,
    );
    expect(move.madeBy, white);
    expect(game.validateMove(move), isTrue);
  });

  test('searching never changes the game it is given', () {
    final game = ShoveGame(white, black);
    game.move(game.getAllLegalMoves().first);
    final key = game.positionKey;

    ShoveSearch(game).findBestMove(timeLimit: quick);

    expect(game.positionKey, key);
    expect(game.allMadeMoves.length, 1);
    expect(game.currentPlayersTurn, black);
  });

  test('stops a shover that is about to reach the goal', () {
    final game = emptyGame(white, black);
    place(game, 1, 3, ShovePiece.shover(white));
    place(game, 6, 7, ShovePiece.shover(white));
    place(game, 0, 5, ShovePiece.blocker(black));
    place(game, 2, 0, ShovePiece.shover(black));
    game.currentPlayersTurn = black;

    final result = ShoveSearch(game).findBestMove(timeLimit: quick)!;
    game.move(result.move);

    expect(game.isGameOver, isFalse);
    for (final reply in game.getAllLegalMoves()) {
      game.move(reply);
      expect(
        game.gameOverState?.winner,
        isNot(white),
        reason: 'white must not be able to win right away after $reply',
      );
      game.undoLastMove();
    }
  });

  test('respects the time limit', () {
    final game = ShoveGame(white, black);
    final clock = Stopwatch()..start();

    ShoveSearch(game)
        .findBestMove(timeLimit: const Duration(milliseconds: 200));

    expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('evaluation rewards having more material', () {
    final balanced = ShoveGame(white, black);
    final ahead = ShoveGame(white, black);
    final square = ahead.getSquareByXY(0, 2)!;
    ahead.pieces.remove(square.pieceId);
    square.pieceId = null;

    expect(
      ShoveSearch(ahead).evaluate(),
      greaterThan(ShoveSearch(balanced).evaluate()),
    );
  });

  test('evaluation rewards advanced shovers', () {
    final advanced = emptyGame(white, black);
    final back = emptyGame(white, black);
    place(advanced, 2, 0, ShovePiece.shover(white));
    place(back, 6, 0, ShovePiece.shover(white));
    for (final game in [advanced, back]) {
      place(game, 1, 7, ShovePiece.shover(black));
    }

    expect(
      ShoveSearch(advanced).evaluate(),
      greaterThan(ShoveSearch(back).evaluate()),
    );
  });
}
