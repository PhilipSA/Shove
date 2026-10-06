import 'package:flutter_test/flutter_test.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_notation.dart';
import 'package:shove/game_objects/shove_player.dart';

ShoveGame newGame() =>
    ShoveGame(ShovePlayer('Alice', true), ShovePlayer('Bob', false));

void main() {
  test('a played game survives format, parse and replay', () {
    final original = newGame();
    for (var i = 0; i < 60 && !original.isGameOver; i++) {
      final moves = original.getAllLegalMoves();
      original.move(moves[(i * 7) % moves.length]);
    }
    expect(original.allMadeMoves.length, greaterThan(20));

    final text = ShoveGameNotation.format(original);
    final notation = ShoveGameNotation.parse(text);
    expect(notation.white, 'Alice');
    expect(notation.black, 'Bob');

    final replayed = newGame();
    notation.replayOn(replayed);
    expect(replayed.allMadeMoves.length, original.allMadeMoves.length);
    expect(replayed.positionKey, original.positionKey);
    expect(replayed.gameOverReason, original.gameOverReason);
  });

  test('reads move numbers, separators, comments and results', () {
    final notation = ShoveGameNotation.parse('''
[Event "x"]
1.a2-a3 {first} h7×h6 ; ignored
2. b2→b3 1-0
''');
    expect(notation.moves.map((m) => m.text), ['a2-a3', 'h7×h6', 'b2→b3']);
    expect(notation.white, isNull);
  });

  test('reports garbage and illegal moves', () {
    expect(
      () => ShoveGameNotation.parse('1. hello'),
      throwsA(isA<FormatException>()),
    );
    expect(() => ShoveGameNotation.parse(''), throwsA(isA<FormatException>()));

    final notation = ShoveGameNotation.parse('1. a2-a5');
    expect(
      () => notation.replayOn(newGame()),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Move 1'),
        ),
      ),
    );
  });
}
