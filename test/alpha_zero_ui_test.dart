import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/ai/alpha_zero/alpha_zero_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/interactor/shove_game_interactor.dart';
import 'package:shove/ui/game_board/board_widget.dart';
import 'package:shove/ui/game_board/shove_board_view.dart';
import 'package:shove/ui/play/model_file_picker.dart';
import 'package:shove/ui/play/player_selection_widget.dart';

import 'alpha_zero_helpers.dart';
import 'test_helpers.dart';

/// An AI whose moves are controlled by the test.
class ScriptedAi extends IPlayer implements IAi {
  final Future<ShoveGameMove> Function(ShoveGame game) answer;
  int calls = 0;

  ScriptedAi(super.playerName, super.isWhite, this.answer);

  @override
  Future<ShoveGameMove> makeMove(ShoveGame game) {
    calls++;
    return answer(game);
  }
}

late MockAudioPlayers audio;

void main() {
  setUp(() => audio = MockAudioPlayers());

  group('player selection', () {
    final picks = <FutureOr<PickedModelFile?> Function()>[];

    Future<void> pumpPlayers(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PlayersWidget(
            audio.create(),
            createAudioPlayer: audio.create,
            pickModelFile: () async => picks.removeAt(0)(),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), 'Alice');
      await tester.enterText(find.byType(TextField).at(1), 'Zero');
    }

    Future<void> selectAlphaZeroForBlack(WidgetTester tester) async {
      await tester.tap(
        find.byWidgetPredicate((w) => w is DropdownButton).at(1),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('alphaZeroAi').last);
      await tester.pumpAndSettle();
    }

    bool startEnabled(WidgetTester tester) =>
        tester
            .widget<ButtonStyleButton>(
              find.ancestor(
                of: find.text('Start Game'),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              ),
            )
            .onPressed !=
        null;

    testWidgets('Start Game waits for a valid uploaded model', (tester) async {
      await pumpPlayers(tester);
      await selectAlphaZeroForBlack(tester);

      expect(find.text('Upload AlphaZero model'), findsOneWidget);
      expect(startEnabled(tester), isFalse);

      picks.add(() => (name: 'broken.json', text: '{"format": 1}'));
      await tester.tap(find.text('Upload AlphaZero model'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('broken.json is not a usable AlphaZero model'),
        findsOneWidget,
      );
      expect(startEnabled(tester), isFalse);

      picks.add(() => null); // Cancelled picker changes nothing.
      await tester.tap(find.text('Upload AlphaZero model'));
      await tester.pumpAndSettle();
      expect(startEnabled(tester), isFalse);

      picks.add(() => (name: 'champion.json', text: syntheticWeights()));
      await tester.tap(find.text('Upload AlphaZero model'));
      await tester.pumpAndSettle();
      expect(find.textContaining('champion.json'), findsOneWidget);
      expect(find.textContaining('local-policy residual head'), findsOneWidget);
      expect(find.textContaining('not a usable'), findsNothing);
      expect(startEnabled(tester), isTrue);

      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();
      final game = tester.widget<BoardWidget>(find.byType(BoardWidget)).game;
      final zero = game.player2 as AlphaZeroAi;
      expect(zero.playerName, 'Zero');
      expect(zero.isWhite, isFalse);
      expect(zero.model!.fileName, 'champion.json');
      expect(zero.thinkTime, const Duration(seconds: 3));
      expect(zero.useWorker, isTrue);
      expect(find.text('Zero (AI)'), findsOneWidget);

      // Leaving the board disposes it; nothing was thinking, so nothing fails.
      Navigator.of(tester.element(find.byType(BoardWidget))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('the picker error is shown when upload is unavailable', (
      tester,
    ) async {
      await pumpPlayers(tester);
      await selectAlphaZeroForBlack(tester);
      picks.add(() => throw UnsupportedError('needs the web build'));
      await tester.tap(find.text('Upload AlphaZero model'));
      await tester.pumpAndSettle();
      expect(find.textContaining('needs the web build'), findsOneWidget);
      expect(startEnabled(tester), isFalse);
    });
  });

  group('AI failures', () {
    final human = ShovePlayer('Alice', true);

    test(
      'a failing AI stops the loop with an error instead of retrying',
      () async {
        final ai = ScriptedAi(
          'Zero',
          false,
          (_) async => throw StateError('boom'),
        );
        final game = ShoveGame(human, ai);
        final interactor = ShoveGameInteractor(
          game,
          createAudioPlayer: audio.create,
        );

        await interactor.makeMove(moveOf(game, (6, 0), (5, 0)));

        expect(ai.calls, 1);
        expect(interactor.shoveGameMoveState.aiError, contains('boom'));
        expect(interactor.shoveGameMoveState.aiError, contains('Zero'));
        expect(interactor.shoveGameMoveState.isAiThinking, isFalse);
        expect(interactor.canUndo, isTrue);

        await interactor.processAiTurns();
        expect(ai.calls, 1, reason: 'paused until retried');

        await interactor.retryAi();
        expect(ai.calls, 2);

        interactor.undo();
        expect(interactor.shoveGameMoveState.aiError, isNull);
        expect(game.allMadeMoves, isEmpty);
        expect(interactor.isHumansTurn, isTrue);
        interactor.dispose();
      },
    );

    test('duplicate AI processing does not start a second search', () async {
      final answer = Completer<ShoveGameMove>();
      final ai = ScriptedAi('Zero', true, (_) => answer.future);
      final game = ShoveGame(ai, ShovePlayer('Bob', false));
      final interactor = ShoveGameInteractor(
        game,
        createAudioPlayer: audio.create,
      );
      final loop = interactor.processAiTurns();
      await interactor.processAiTurns();
      await interactor.retryAi();
      expect(ai.calls, 1);
      answer.complete(game.getAllLegalMoves().first);
      await loop;
      expect(game.allMadeMoves.length, 1);
      expect(interactor.shoveGameMoveState.aiError, isNull);
      interactor.dispose();
    });

    test('disposing while the AI thinks swallows its late failure', () async {
      final answer = Completer<ShoveGameMove>();
      final ai = ScriptedAi('Zero', true, (_) => answer.future);
      final interactor = ShoveGameInteractor(
        ShoveGame(ai, ShovePlayer('Bob', false)),
        createAudioPlayer: audio.create,
      );
      final loop = interactor.processAiTurns();
      interactor.dispose();
      answer.completeError(StateError('stopped'));
      await loop;
      expect(ai.calls, 1);
    });

    test('closing the board stops an AlphaZero search for that game', () async {
      final zero = AlphaZeroAi.withModel(
        'Zero',
        true,
        syntheticModel,
        thinkTime: const Duration(seconds: 5),
      );
      final interactor = ShoveGameInteractor(
        ShoveGame(zero, ShovePlayer('Bob', false)),
        createAudioPlayer: audio.create,
      );
      final loop = interactor.processAiTurns();
      await Future<void>.delayed(Duration.zero);
      final clock = Stopwatch()..start();
      interactor.dispose();
      await loop;
      expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    });

    testWidgets('the board shows the AI error with a retry button', (
      tester,
    ) async {
      final ai = ScriptedAi(
        'Zero',
        true,
        (_) async => throw StateError('boom'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ShoveBoardWidget(
            game: ShoveGame(ai, ShovePlayer('Bob', false)),
            musicPlayer: audio.create(),
            createAudioPlayer: audio.create,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Zero could not move'), findsOneWidget);
      expect(find.text('Retry AI'), findsOneWidget);

      await tester.tap(find.text('Retry AI'));
      await tester.pump();
      await tester.pump();
      expect(ai.calls, 2);
    });
  });

  testWidgets('rematch keeps the same AlphaZero player and model', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final zero = AlphaZeroAi.withModel('Zero', false, syntheticModel);
    final game = ShoveGame(ShovePlayer('Alice', true), zero);
    // White wins with its first move, so AlphaZero never has to think.
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
        home: ShoveBoardWidget(
          game: game,
          musicPlayer: audio.create(),
          createAudioPlayer: audio.create,
        ),
      ),
    );
    await tester.pump();
    Offset center(int x, int y) {
      final rect = tester.getRect(find.byType(BoardWidget));
      final frame = max(2.0, rect.width * 0.012);
      final cell = (rect.width - frame * 2) / ShoveGame.totalNumberOfColumns;
      return rect.topLeft +
          Offset(frame + (y + 0.5) * cell, frame + (x + 0.5) * cell);
    }

    await tester.tapAt(center(1, 0));
    await tester.pump();
    await tester.tapAt(center(0, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(game.isGameOver, isTrue);
    await tester.tap(find.text('Rematch').first);
    await tester.pump();

    final rematch = tester.widget<BoardWidget>(find.byType(BoardWidget)).game;
    expect(identical(rematch, game), isFalse);
    expect(identical(rematch.player2, zero), isTrue);
    expect(zero.model, same(syntheticModel));
    expect(rematch.allMadeMoves, isEmpty);
    expect(rematch.pieces.length, 32);
    await tester.pump(const Duration(seconds: 1));
  });
}
