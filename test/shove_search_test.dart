import 'package:flutter_test/flutter_test.dart';
import 'package:shove/ai/min_max/min_max_ai.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_player.dart';

import 'test_helpers.dart';

final white = ShovePlayer('white', true);
final black = ShovePlayer('black', false);

const quick = Duration(milliseconds: 300);

Future<ShoveGameMove> search(ShoveGame game, {Duration thinkTime = quick}) =>
    MinMaxAi(
      game.currentPlayersTurn.playerName,
      game.currentPlayersTurn.isWhite,
      thinkTime: thinkTime,
      useWorker: false,
    ).makeMove(game);

void main() {
  test('throws when the side to move has no legal moves', () {
    final game = emptyGame(white, black);
    place(game, 6, 0, ShovePiece.shover(white));
    place(game, 1, 5, ShovePiece.shover(black)).isIncapacitated = true;
    game.currentPlayersTurn = black;

    expect(search(game), throwsStateError);
  });

  test('finds a win in one', () async {
    final game = emptyGame(white, black);
    place(game, 1, 3, ShovePiece.shover(white));
    place(game, 6, 6, ShovePiece.shover(black));

    final move = await search(game);

    expect((move.newSquare.x, move.newSquare.y), (0, 3));
  });

  test('returned move uses the squares of the game passed in', () async {
    final game = ShoveGame(white, black);

    final move = await search(game);

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

  test('searching never changes the game it is given', () async {
    final game = ShoveGame(white, black);
    game.move(game.getAllLegalMoves().first);
    final key = game.positionKey;

    await search(game);

    expect(game.positionKey, key);
    expect(game.allMadeMoves.length, 1);
    expect(game.currentPlayersTurn, black);
  });

  test('stops a shover that is about to reach the goal', () async {
    final game = emptyGame(white, black);
    place(game, 1, 3, ShovePiece.shover(white));
    place(game, 6, 7, ShovePiece.shover(white));
    place(game, 0, 5, ShovePiece.blocker(black));
    place(game, 2, 0, ShovePiece.shover(black));
    game.currentPlayersTurn = black;

    game.move(await search(game));

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

  test('respects the time limit', () async {
    final game = ShoveGame(white, black);
    final clock = Stopwatch()..start();

    await search(game, thinkTime: const Duration(milliseconds: 200));

    expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
