import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/ui/game_board/board_widget.dart';
import 'package:shove/ui/game_board/move_animation.dart';

final white = ShovePlayer('Alice', true);
final black = ShovePlayer('Bob', false);

Widget board(ShoveGame game) => MaterialApp(
  home: Scaffold(
    body: BoardWidget(game: game, isInteractive: true, onMove: (_) {}),
  ),
);

void main() {
  test('a plain move slides the piece and hides its destination', () {
    final game = ShoveGame(white, black);
    final move = game.getLegalMovesFrom(game.getSquareByXY(6, 0)!).first;
    game.move(move);

    final animation = MoveAnimation.of(game, move)!;

    expect(animation.flights, hasLength(1));
    expect(animation.flights.single.style, FlightStyle.slide);
    expect(animation.hidden, {(move.newSquare.x, move.newSquare.y)});
  });

  test('a leap hops the piece', () {
    final game = ShoveGame(white, black);
    final move = game
        .getLegalMovesFrom(game.getSquareByXY(7, 1)!)
        .firstWhere((m) => (m.newSquare.x - m.oldSquare.x).abs() == 2);
    game.move(move);

    final animation = MoveAnimation.of(game, move)!;

    expect(animation.flights.single.style, FlightStyle.hop);
    expect(animation.flights.single.lift(0.45), closeTo(1, 1e-9));
  });

  testWidgets('a new move plays an animation that ends by itself', (
    tester,
  ) async {
    final game = ShoveGame(white, black);
    await tester.pumpWidget(board(game));
    expect(find.byType(MoveAnimationOverlay), findsNothing);

    final ShoveGameMove move = game
        .getLegalMovesFrom(game.getSquareByXY(6, 0)!)
        .first;
    game.move(move);
    await tester.pumpWidget(board(game));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MoveAnimationOverlay), findsOneWidget);

    await tester.pump(MoveAnimation.duration);
    await tester.pump();
    expect(find.byType(MoveAnimationOverlay), findsNothing);
  });

  testWidgets('undoing a move does not animate', (tester) async {
    final game = ShoveGame(white, black);
    game.move(game.getLegalMovesFrom(game.getSquareByXY(6, 0)!).first);
    await tester.pumpWidget(board(game));

    game.undoLastMove();
    await tester.pumpWidget(board(game));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MoveAnimationOverlay), findsNothing);
  });
}
