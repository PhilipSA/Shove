import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shove/main.dart';
import 'package:shove/puzzles/shove_puzzles.dart';
import 'package:shove/ui/game_board/board_widget.dart';

import '../test_helpers.dart';

late MockAudioPlayers audio;

Offset squareCenter(WidgetTester tester, int x, int y) {
  final rect = tester.getRect(find.byType(BoardWidget));
  final frame = max(2.0, rect.width * 0.012);
  final cell = (rect.width - frame * 2) / 8;
  return rect.topLeft +
      Offset(frame + (y + 0.5) * cell, frame + (x + 0.5) * cell);
}

Future<void> tapSquare(WidgetTester tester, int x, int y) async {
  await tester.tapAt(squareCenter(tester, x, y));
  await tester.pump();
}

Future<void> openPuzzle(WidgetTester tester, String title) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MyApp(createAudioPlayer: audio.create));
  await tester.tap(find.text('Puzzles'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => audio = MockAudioPlayers());

  testWidgets('the start screen lists the puzzles', (tester) async {
    await tester.pumpWidget(MyApp(createAudioPlayer: audio.create));
    await tester.tap(find.text('Puzzles'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('0 of ${shovePuzzles.length} solved'),
      findsOneWidget,
    );
    expect(find.text(shovePuzzles.first.title), findsOneWidget);
  });

  testWidgets('a puzzle can be solved and marks the list', (tester) async {
    await openPuzzle(tester, 'Hop to the goal');

    expect(find.text('Puzzle 1 of ${shovePuzzles.length}'), findsOneWidget);
    expect(find.textContaining('Your move: win in 1 move.'), findsOneWidget);

    await tapSquare(tester, 2, 5);
    await tapSquare(tester, 0, 5);

    expect(find.text('Solved on the first try!'), findsOneWidget);
    expect(find.text('Next puzzle'), findsOneWidget);

    await tester.tap(find.text('Next puzzle'));
    await tester.pumpAndSettle();
    expect(find.text('Puzzle 2 of ${shovePuzzles.length}'), findsOneWidget);

    await tester.tap(find.byTooltip('Go back'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(
      find.textContaining('1 of ${shovePuzzles.length} solved'),
      findsOneWidget,
    );
  });

  testWidgets('a wrong move is shown and then taken back', (tester) async {
    await openPuzzle(tester, 'Hop to the goal');

    await tapSquare(tester, 6, 2);
    await tapSquare(tester, 5, 2);
    expect(find.text('That does not win. Try again!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Your move: win in 1 move.'), findsOneWidget);
  });

  testWidgets('the hint button reveals the hint text', (tester) async {
    await openPuzzle(tester, 'Hop to the goal');

    await tester.tap(find.text('Hint'));
    await tester.pump();

    expect(find.text(shovePuzzles.first.hint), findsOneWidget);
    expect(find.text('Show piece'), findsOneWidget);
  });
}
