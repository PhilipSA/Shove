import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shove/ai/alpha_zero/alpha_zero_ai.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_player.dart';

void play(ShoveGame game, List<List<int>> moves) {
  for (final tuple in moves) {
    final move = game.getAllLegalMoves().firstWhere(
      (move) => jsonEncode(azMove(move)) == jsonEncode(tuple),
    );
    game.move(move);
  }
}

void main() {
  test('private AlphaZero history copy preserves a real repetition draw', () {
    // A recorded full-board game; copied/frozen history missed this draw.
    const history = [
      [51, 43, 64],
      [13, 21, 64],
      [55, 47, 64],
      [11, 19, 64],
      [47, 46, 64],
      [19, 18, 64],
      [53, 45, 64],
      [5, 13, 64],
      [49, 41, 64],
      [10, 11, 64],
      [43, 44, 64],
      [21, 29, 64],
      [41, 40, 64],
      [11, 10, 64],
      [59, 3, 64],
      [18, 17, 64],
      [45, 37, 64],
      [17, 25, 64],
      [44, 36, 64],
      [25, 33, 64],
      [52, 44, 64],
      [29, 37, 64],
      [61, 52, 64],
      [37, 45, 64],
      [58, 49, 64],
      [45, 44, 64],
      [49, 41, 64],
      [33, 41, 64],
      [43, 44, 64],
      [41, 42, 64],
      [53, 45, 64],
      [42, 50, 64],
      [50, 42, 49],
      [37, 45, 64],
      [58, 50, 64],
      [42, 50, 64],
      [50, 42, 49],
      [45, 53, 64],
      [53, 45, 52],
      [6, 20, 64],
      [58, 50, 64],
      [42, 50, 64],
      [50, 42, 49],
      [13, 5, 64],
      [58, 50, 64],
      [42, 50, 64],
      [50, 42, 49],
      [14, 13, 64],
      [58, 50, 64],
      [42, 50, 64],
      [50, 42, 49],
      [45, 53, 64],
      [61, 53, 64],
      [42, 50, 64],
      [58, 50, 64],
      [45, 53, 64],
      [53, 45, 52],
      [42, 50, 64],
      [50, 41, 49],
      [45, 46, 64],
      [54, 46, 64],
      [41, 42, 64],
      [61, 53, 64],
      [38, 46, 64],
      [47, 46, 64],
      [42, 50, 64],
      [58, 50, 64],
      [45, 53, 64],
      [53, 45, 52],
      [42, 50, 64],
      [50, 41, 49],
      [45, 46, 64],
      [54, 46, 64],
      [41, 42, 64],
      [61, 53, 64],
      [38, 46, 64],
      [47, 46, 64],
      [42, 50, 64],
      [58, 50, 64],
      [45, 53, 64],
    ];
    const continuation = [
      [53, 45, 52],
      [42, 50, 64],
      [50, 42, 49],
    ];
    final live = ShoveGame(
      ShovePlayer('white', true),
      ShovePlayer('black', false),
    );
    play(live, history);
    final before = jsonEncode(azBoard(live));
    final copy = copyAlphaZeroSearchGame(live);
    play(copy, continuation);
    expect(copy.isGameOver, isTrue);
    expect(copy.gameOverReason, GameOverReason.repetition);
    expect(copy.gameOverState!.winner, isNull);
    expect(live.isGameOver, isFalse);
    expect(live.allMadeMoves.length, 80);
    expect(jsonEncode(azBoard(live)), before);
    play(live, continuation);
    expect(live.gameOverReason, copy.gameOverReason);
    expect(live.positionKey, copy.positionKey);
  });
}
