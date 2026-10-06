import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/ai/min_max/min_max_ai.dart';
import 'package:shove/ai/random_ai.dart';
import 'package:shove/game_objects/shove_game.dart';

void main() {
  test('finds a win in one', () async {
    final ai = MinMaxAi('ai', true, useWorker: false);
    final game = ShoveGame(ai, RandomAi('random', false));
    final from = game.getSquareByXY(6, 0)!;
    final nextToGoal = game.getSquareByXY(1, 0)!;
    game.pieces.remove(game.getSquareByXY(0, 0)!.pieceId);
    game.getSquareByXY(0, 0)!.pieceId = null;
    game.pieces.remove(nextToGoal.pieceId);
    nextToGoal.pieceId = from.pieceId;
    from.pieceId = null;

    final move = await ai.makeMove(game);

    expect((move.newSquare.x, move.newSquare.y), (0, 0));
    expect(identical(move.newSquare, game.getSquareByXY(0, 0)), isTrue);
  });

  test('thinking never changes the game it is given', () async {
    final white = RandomAi('white', true, random: Random(5));
    final black = MinMaxAi('black', false, useWorker: false);
    final game = ShoveGame(white, black);
    final warmUp = RandomAi('black', false, random: Random(6));
    for (var i = 0; i < 12; i++) {
      final ai = game.currentPlayersTurn == white ? white : warmUp;
      game.move(await ai.makeMove(game));
    }
    final key = game.positionKey;
    final history = game.allMadeMoves.length;

    await black.makeMove(game);

    expect(game.positionKey, key);
    expect(game.allMadeMoves.length, history);
    expect(game.isGameOver, isFalse);
  });

  test('MinMaxAi beats RandomAi every time', () async {
    for (var seed = 0; seed < 4; seed++) {
      final smart = MinMaxAi(
        'smart',
        true,
        thinkTime: const Duration(milliseconds: 100),
        useWorker: false,
      );
      final random = RandomAi('random', false, random: Random(seed));
      final game = ShoveGame(smart, random);

      for (var ply = 0; ply < 300 && !game.isGameOver; ply++) {
        final ai = game.currentPlayersTurn as IAi;
        game.move(await ai.makeMove(game));
      }
      expect(game.gameOverState?.winner, smart, reason: 'seed $seed');
    }
  });
}
