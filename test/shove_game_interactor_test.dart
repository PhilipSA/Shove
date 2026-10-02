import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shove/ai/random_ai.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/interactor/shove_game_interactor.dart';
import 'package:shove/resources/shove_assets.dart';

import 'test_helpers.dart';

final human = ShovePlayer('human', true);

late MockAudioPlayers audio;

ShoveGameInteractor interactorFor(ShoveGame game) =>
    ShoveGameInteractor(game, createAudioPlayer: audio.create);

List<String> playedSounds() => [
  for (final player in audio.created)
    for (final source in verify(player.play(captureAny)).captured)
      (source as AssetSource).path,
];

void main() {
  setUp(() => audio = MockAudioPlayers());

  test('a human move is applied and notifies listeners', () async {
    final game = ShoveGame(human, ShovePlayer('other', false));
    final interactor = interactorFor(game);
    var notified = 0;
    interactor.shoveGameMoveState.addListener(() => notified++);

    await interactor.makeMove(moveOf(game, (6, 0), (5, 0)));

    expect(game.allMadeMoves.length, 1);
    expect(game.getSquareByXY(5, 0)!.pieceId, isNotNull);
    expect(notified, greaterThan(0));
    interactor.dispose();
  });

  test('every move plays its sound', () async {
    final other = ShovePlayer('other', false);
    final game = emptyGame(human, other);
    place(game, 4, 1, ShovePiece.shover(human));
    place(game, 4, 0, ShovePiece.thrower(other));
    place(game, 1, 7, ShovePiece.shover(other));
    final interactor = interactorFor(game);

    await interactor.makeMove(moveOf(game, (4, 1), (4, 0)));
    await interactor.makeMove(moveOf(game, (1, 7), (2, 7)));

    expect(playedSounds(), [
      AudioAssets.scream.assetPath,
      AudioAssets.move.assetPath,
    ]);
    interactor.dispose();
  });

  test('illegal moves are ignored', () async {
    final game = ShoveGame(human, ShovePlayer('other', false));
    final interactor = interactorFor(game);
    final key = game.positionKey;

    await interactor.makeMove(moveOf(game, (6, 0), (4, 0)));
    await interactor.makeMove(moveOf(game, (1, 0), (2, 0)));

    expect(game.positionKey, key);
    expect(game.allMadeMoves, isEmpty);
    expect(audio.created, isEmpty);
    interactor.dispose();
  });

  test('moves are ignored while it is the AI\'s turn', () async {
    final ai = RandomAi('ai', true, random: Random(1));
    final game = ShoveGame(ai, human);
    final interactor = interactorFor(game);

    expect(interactor.isHumansTurn, isFalse);
    await interactor.makeMove(moveOf(game, (6, 0), (5, 0)));
    expect(game.allMadeMoves, isEmpty);
    interactor.dispose();
  });

  test('the AI replies to a human move', () async {
    final game = ShoveGame(human, RandomAi('ai', false, random: Random(2)));
    final interactor = interactorFor(game);

    await interactor.makeMove(moveOf(game, (6, 0), (5, 0)));

    expect(game.allMadeMoves.length, 2);
    expect(game.currentPlayersTurn, human);
    expect(interactor.isHumansTurn, isTrue);
    expect(interactor.shoveGameMoveState.isAiThinking, isFalse);
    interactor.dispose();
  });

  test('undo takes back the AI reply together with the human move', () async {
    final game = ShoveGame(human, RandomAi('ai', false, random: Random(3)));
    final interactor = interactorFor(game);
    final key = game.positionKey;
    expect(interactor.canUndo, isFalse);

    await interactor.makeMove(moveOf(game, (6, 0), (5, 0)));
    expect(interactor.canUndo, isTrue);

    interactor.undo();

    expect(game.allMadeMoves, isEmpty);
    expect(game.positionKey, key);
    expect(game.currentPlayersTurn, human);
    expect(interactor.canUndo, isFalse);
    interactor.dispose();
  });

  test('undo only takes back the last move between two humans', () async {
    final game = ShoveGame(human, ShovePlayer('other', false));
    final interactor = interactorFor(game);

    await interactor.makeMove(moveOf(game, (6, 0), (5, 0)));
    await interactor.makeMove(moveOf(game, (1, 0), (2, 0)));
    interactor.undo();

    expect(game.allMadeMoves.length, 1);
    expect(game.currentPlayersTurn.playerName, 'other');
    interactor.dispose();
  });

  test('cannot undo moves made only by AIs', () async {
    final game = ShoveGame(
      RandomAi('a', true, random: Random(4)),
      RandomAi('b', false, random: Random(5)),
    );
    final interactor = interactorFor(game);
    game.move(game.getAllLegalMoves().first);

    expect(interactor.canUndo, isFalse);
    interactor.undo();
    expect(game.allMadeMoves.length, 1);
    interactor.dispose();
  });

  test('game over state follows the game, including undo', () async {
    final other = ShovePlayer('other', false);
    final game = emptyGame(human, other);
    place(game, 1, 0, ShovePiece.shover(human));
    place(game, 1, 7, ShovePiece.shover(other));
    final interactor = interactorFor(game);

    await interactor.makeMove(moveOf(game, (1, 0), (0, 0)));

    final over = interactor.shoveGameOverState;
    expect(over.isGameOver, isTrue);
    expect(over.winner, human);
    expect(over.reason, GameOverReason.reachedGoal);
    expect(over.isDraw, isFalse);
    expect(interactor.isHumansTurn, isFalse);

    interactor.undo();
    expect(over.isGameOver, isFalse);
    expect(over.winner, isNull);
    expect(interactor.isHumansTurn, isTrue);
    interactor.dispose();
  });

  test('a draw is reported without a winner', () async {
    final other = ShovePlayer('other', false);
    final game = repetitionGame(human, other);
    playUntilOneMoveBeforeRepetition(game);
    final interactor = interactorFor(game);

    await interactor.makeMove(moveOf(game, (2, 3), (2, 4)));

    expect(interactor.shoveGameOverState.isDraw, isTrue);
    expect(interactor.shoveGameOverState.winner, isNull);
    interactor.dispose();
  });

  test('disposing stops the AI from playing on', () async {
    final game = ShoveGame(
      RandomAi('a', true, random: Random(6)),
      RandomAi('b', false, random: Random(7)),
    );
    final interactor = interactorFor(game);

    final playing = interactor.processAiTurns();
    interactor.dispose();
    await playing;

    expect(game.allMadeMoves.length, lessThanOrEqualTo(1));
  });
}
