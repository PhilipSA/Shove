import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shove/ai/random_ai.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/interactor/shove_game_interactor.dart';
import 'package:shove/ui/about/about_board_widget.dart';
import 'package:shove/ui/game_board/board_widget.dart';
import 'package:shove/ui/game_board/evaluation_bar_widget.dart';
import 'package:shove/ui/game_board/shove_board_view.dart';

import 'test_helpers.dart' as h;

final white = ShovePlayer('Alice', true);
final black = ShovePlayer('Bob', false);

late h.MockShoveAudioPlayer music;
late h.MockAudioPlayers sounds;

Widget gameScreen(ShoveGame game) => MaterialApp(
  home: ShoveBoardWidget(
    game: game,
    musicPlayer: music,
    createAudioPlayer: sounds.create,
  ),
);

Offset squareCenter(WidgetTester tester, int x, int y) {
  final rect = tester.getRect(find.byType(BoardWidget));
  final frame = max(2.0, rect.width * 0.012);
  final cell = (rect.width - frame * 2) / ShoveGame.totalNumberOfColumns;
  return rect.topLeft +
      Offset(frame + (y + 0.5) * cell, frame + (x + 0.5) * cell);
}

Finder byTypeName(String name) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

Future<void> pumpBoard(
  WidgetTester tester,
  ShoveGame game, {
  bool isInteractive = true,
  ValueChanged<ShoveGameMove>? onMove,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: BoardWidget(
        game: game,
        isInteractive: isInteractive,
        onMove: onMove ?? (_) {},
      ),
    ),
  ),
);

Future<void> pumpGameScreen(WidgetTester tester, ShoveGame game) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(gameScreen(game));
  await tester.pump();
}

Future<void> tapMove(
  WidgetTester tester,
  (int, int) from,
  (int, int) to,
) async {
  await tester.tapAt(squareCenter(tester, from.$1, from.$2));
  await tester.pump();
  await tester.tapAt(squareCenter(tester, to.$1, to.$2));
  await tester.pump();
}

VoidCallback? undoAction(WidgetTester tester) => tester
    .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo))
    .onPressed;

void main() {
  setUp(() {
    music = h.MockShoveAudioPlayer();
    sounds = h.MockAudioPlayers();
  });

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

      await tester.pumpWidget(gameScreen(ShoveGame(white, black)));
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

    await tester.pumpWidget(gameScreen(game));
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

  group('board', () {
    testWidgets('ignores taps when not interactive', (tester) async {
      ShoveGameMove? played;
      await pumpBoard(
        tester,
        ShoveGame(white, black),
        isInteractive: false,
        onMove: (m) => played = m,
      );

      await tapMove(tester, (6, 0), (5, 0));

      expect(byTypeName('_MoveHint'), findsNothing);
      expect(played, isNull);
    });

    testWidgets('tapping the selected piece again deselects it', (
      tester,
    ) async {
      await pumpBoard(tester, ShoveGame(white, black));

      await tester.tapAt(squareCenter(tester, 7, 1));
      await tester.pump();
      expect(byTypeName('_MoveHint'), findsNWidgets(2));

      await tester.tapAt(squareCenter(tester, 7, 1));
      await tester.pump();
      expect(byTypeName('_MoveHint'), findsNothing);
    });

    testWidgets('opponent pieces cannot be selected without a thrower', (
      tester,
    ) async {
      await pumpBoard(tester, ShoveGame(white, black));

      await tester.tapAt(squareCenter(tester, 1, 0));
      await tester.pump();

      expect(byTypeName('_MoveHint'), findsNothing);
    });

    testWidgets('an enemy next to your thrower can be thrown by tapping', (
      tester,
    ) async {
      final game = h.emptyGame(white, black);
      h.place(game, 4, 4, ShovePiece.thrower(white));
      h.place(game, 4, 5, ShovePiece.shover(black));
      h.place(game, 6, 0, ShovePiece.shover(white));
      h.place(game, 1, 7, ShovePiece.shover(black));
      ShoveGameMove? played;
      await pumpBoard(tester, game, onMove: (m) => played = m);

      await tester.tapAt(squareCenter(tester, 4, 5));
      await tester.pump();
      expect(byTypeName('_MoveHint'), findsNWidgets(7));

      await tester.tapAt(squareCenter(tester, 3, 3));
      await tester.pump();
      expect(played?.throwerSquare, game.getSquareByXY(4, 4));
      expect((played?.newSquare.x, played?.newSquare.y), (3, 3));
    });

    testWidgets('pieces can be dragged to a legal square', (tester) async {
      ShoveGameMove? played;
      await pumpBoard(
        tester,
        ShoveGame(white, black),
        onMove: (m) => played = m,
      );

      final from = squareCenter(tester, 6, 0);
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveTo(squareCenter(tester, 5, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect((played?.oldSquare.x, played?.oldSquare.y), (6, 0));
      expect((played?.newSquare.x, played?.newSquare.y), (5, 0));
    });

    testWidgets('dropping on an illegal square does not move', (tester) async {
      ShoveGameMove? played;
      await pumpBoard(
        tester,
        ShoveGame(white, black),
        onMove: (m) => played = m,
      );

      final gesture = await tester.startGesture(squareCenter(tester, 6, 0));
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveTo(squareCenter(tester, 3, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(played, isNull);
    });
  });

  group('game screen', () {
    testWidgets('a move updates the status line and can be undone', (
      tester,
    ) async {
      final game = ShoveGame(white, black);
      await pumpGameScreen(tester, game);

      expect(
        find.text('Alice starts. Tap a piece to see its moves.'),
        findsOneWidget,
      );
      expect(undoAction(tester), isNull);

      await tapMove(tester, (6, 0), (5, 0));
      expect(find.text('Alice moved a shover.'), findsOneWidget);
      expect(game.getSquareByXY(5, 0)!.pieceId, isNotNull);
      expect(undoAction(tester), isNotNull);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();

      expect(game.allMadeMoves, isEmpty);
      expect(game.getSquareByXY(5, 0)!.pieceId, isNull);
      expect(
        find.text('Alice starts. Tap a piece to see its moves.'),
        findsOneWidget,
      );
      expect(undoAction(tester), isNull);
    });

    testWidgets('the AI opponent is labelled and replies to a move', (
      tester,
    ) async {
      final game = ShoveGame(white, RandomAi('Bot', false));
      await pumpGameScreen(tester, game);

      expect(find.text('Bot (AI)'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);

      await tapMove(tester, (6, 0), (5, 0));
      await tester.pump(const Duration(milliseconds: 300));

      expect(game.allMadeMoves.length, 2);
      expect(game.currentPlayersTurn, white);
      expect(
        tester.widget<BoardWidget>(find.byType(BoardWidget)).isInteractive,
        isTrue,
      );
      expect(find.textContaining('Bot moved a'), findsOneWidget);
    });

    testWidgets('a repetition draw shows a draw result', (tester) async {
      final game = h.repetitionGame(white, black);
      h.playUntilOneMoveBeforeRepetition(game);
      await pumpGameScreen(tester, game);

      await tapMove(tester, (2, 3), (2, 4));
      await tester.pump(const Duration(milliseconds: 600));

      expect(game.isDraw, isTrue);
      expect(find.text('Draw'), findsWidgets);
      expect(
        find.text('Both players kept repeating the same moves.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.handshake), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('eliminating the last shover explains the win', (tester) async {
      final game = h.emptyGame(white, black);
      h.place(game, 3, 1, ShovePiece.shover(white));
      h.place(game, 3, 0, ShovePiece.shover(black));
      h.place(game, 0, 7, ShovePiece.thrower(black));
      await pumpGameScreen(tester, game);

      await tapMove(tester, (3, 1), (3, 0));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Alice wins!'), findsWidgets);
      expect(find.text('Bob has no shovers left.'), findsOneWidget);
      expect(find.text('Winner!'), findsOneWidget);
    });

    testWidgets('"Result" brings back a dismissed result', (tester) async {
      final game = h.emptyGame(white, black);
      h.place(game, 3, 1, ShovePiece.shover(white));
      h.place(game, 3, 0, ShovePiece.shover(black));
      await pumpGameScreen(tester, game);

      await tapMove(tester, (3, 1), (3, 0));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('View board'));
      await tester.pump();
      expect(find.text('Bob has no shovers left.'), findsNothing);

      await tester.tap(find.text('Result'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Bob has no shovers left.'), findsOneWidget);
    });

    testWidgets('the rules can be opened from the game', (tester) async {
      await pumpGameScreen(tester, ShoveGame(white, black));

      await tester.tap(find.byTooltip('Rules'));
      await tester.pumpAndSettle();

      expect(find.byType(About), findsOneWidget);
    });

    testWidgets('music starts with the game and can be muted and resumed', (
      tester,
    ) async {
      await pumpGameScreen(tester, ShoveGame(white, black));
      final musicPath = verify(
        music.play(captureAny, volume: anyNamed('volume')),
      ).captured.single;
      expect((musicPath as AssetSource).path, 'sounds/music/game_music.mp3');

      await tester.tap(find.byTooltip('Mute music'));
      await tester.pump();
      expect(find.byIcon(Icons.music_off), findsOneWidget);
      verify(music.stop()).called(2);
      verifyNever(music.play(any, volume: anyNamed('volume')));

      await tester.tap(find.byTooltip('Play music'));
      await tester.pump();
      expect(find.byIcon(Icons.music_note), findsOneWidget);
      verify(music.play(any, volume: anyNamed('volume'))).called(1);
    });

    testWidgets('moves play a sound and leaving disposes the music', (
      tester,
    ) async {
      await pumpGameScreen(tester, ShoveGame(white, black));

      await tapMove(tester, (6, 0), (5, 0));
      expect(sounds.created, hasLength(1));
      verify(sounds.created.single.play(any)).called(1);

      await tester.pumpWidget(const SizedBox());
      verify(music.dispose()).called(1);
    });
  });

  testWidgets('evaluation bar handles the full evaluation range', (
    tester,
  ) async {
    final state = ShoveGameEvaluationState();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 18,
            height: 300,
            child: ChangeNotifierProvider.value(
              value: state,
              child: EvaluationBarWidget(shoveGameEvaluationState: state),
            ),
          ),
        ),
      ),
    );

    for (final value in [10.0, -10.0, 3.5, 0.0]) {
      state.evaluation = value;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: 'evaluation $value');
    }
  });
}
