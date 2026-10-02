import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/ui/game_board/board_widget.dart';
import 'package:shove/ui/game_board/shove_board_view.dart';

final white = ShovePlayer('Alice', true);
final black = ShovePlayer('Bob', false);

void mockAudioPlugin() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in [
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }
}

Offset squareCenter(WidgetTester tester, int x, int y) {
  final rect = tester.getRect(find.byType(BoardWidget));
  final frame = max(2.0, rect.width * 0.012);
  final cell = (rect.width - frame * 2) / ShoveGame.totalNumberOfColumns;
  return rect.topLeft +
      Offset(frame + (y + 0.5) * cell, frame + (x + 0.5) * cell);
}

Finder byTypeName(String name) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

void main() {
  setUp(mockAudioPlugin);

  testWidgets('tapping a piece shows its legal moves and tapping one moves', (
    tester,
  ) async {
    final game = ShoveGame(white, black);
    ShoveGameMove? played;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardWidget(
            game: game,
            isInteractive: true,
            onMove: (m) => played = m,
          ),
        ),
      ),
    );

    expect(byTypeName('_MoveHint'), findsNothing);

    // Leaper on the back rank can leap over the shovers in front of it
    await tester.tapAt(squareCenter(tester, 7, 1));
    await tester.pump();
    expect(byTypeName('_MoveHint'), findsNWidgets(2));

    await tester.tapAt(squareCenter(tester, 5, 1));
    await tester.pump();
    expect(played?.newSquare.x, 5);
    expect(played?.newSquare.y, 1);
    expect(byTypeName('_MoveHint'), findsNothing);
  });

  testWidgets('stunned pieces are clearly marked', (tester) async {
    final game = ShoveGame(white, black);
    game.pieces[game.getSquareByXY(1, 3)!.pieceId]!.isIncapacitated = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardWidget(game: game, isInteractive: false, onMove: (_) {}),
        ),
      ),
    );

    expect(byTypeName('_StunnedPiece'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_bottom), findsOneWidget);
  });

  const screenSizes = {
    'small phone': Size(320, 568),
    'phone': Size(390, 844),
    'phone landscape': Size(844, 390),
    'tablet': Size(820, 1180),
    'desktop': Size(1920, 1080),
    'ultrawide': Size(2560, 900),
  };

  for (final entry in screenSizes.entries) {
    testWidgets('game screen fits on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: ShoveBoardWidget(
            game: ShoveGame(white, black),
            musicPlayer: ShoveAudioPlayer(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final board = tester.getRect(find.byType(BoardWidget));
      expect(board.width, closeTo(board.height, 0.5));
      // Board should use a good part of the shortest screen side
      expect(board.width, greaterThan(entry.value.shortestSide * 0.45));
      expect(
        Offset.zero & entry.value,
        predicate<Rect>(
          (screen) => screen.contains(board.bottomRight - const Offset(1, 1)),
        ),
      );
    });
  }

  testWidgets('winning shows a clear result overlay with rematch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final game = ShoveGame(white, black);
    // Clear a path: remove black's piece in front of white's shover on column 0
    for (final x in [0, 1, 2, 3, 4, 5]) {
      final square = game.getSquareByXY(x, 0)!;
      game.pieces.remove(square.pieceId);
      square.pieceId = null;
    }
    final shover = game.pieces.remove(game.getSquareByXY(6, 0)!.pieceId)!;
    game.getSquareByXY(6, 0)!.pieceId = null;
    game.getSquareByXY(1, 0)!.pieceId = shover.id;
    game.pieces[shover.id] = shover;

    await tester.pumpWidget(
      MaterialApp(
        home: ShoveBoardWidget(game: game, musicPlayer: ShoveAudioPlayer()),
      ),
    );
    await tester.pump();

    await tester.tapAt(squareCenter(tester, 1, 0));
    await tester.pump();
    await tester.tapAt(squareCenter(tester, 0, 0));
    await tester.pump(const Duration(milliseconds: 600));

    expect(game.isGameOver, isTrue);
    expect(find.text('Alice wins!'), findsWidgets);
    expect(find.text('Alice got a shover to the back rank.'), findsOneWidget);
    expect(find.text('Rematch'), findsWidgets);

    await tester.tap(find.text('View board'));
    await tester.pump();
    expect(find.text('Alice got a shover to the back rank.'), findsNothing);

    await tester.tap(find.text('Rematch').first);
    await tester.pump();
    expect(find.text('Alice wins!'), findsNothing);
    expect(find.byType(BoardWidget), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
