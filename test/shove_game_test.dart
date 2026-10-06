import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shove/ai/min_max_ai.dart';
import 'package:shove/ai/random_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_game_move_dto.dart';
import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
import 'package:shove/game_objects/dto/shove_player_dto.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/resources/shove_assets.dart';

import 'test_helpers.dart';

final white = ShovePlayer('white', true);
final black = ShovePlayer('black', false);

/// Empty board with one shover each, so the game is not over by default.
ShoveGame sparseGame() {
  final game = emptyGame(white, black);
  place(game, 6, 7, ShovePiece.shover(white));
  place(game, 1, 7, ShovePiece.shover(black));
  return game;
}

ShoveGame playRandomly(int plies, {int seed = 3}) {
  final game = ShoveGame(white, black);
  final random = Random(seed);
  for (var i = 0; i < plies && !game.isGameOver; i++) {
    final moves = game.getAllLegalMoves();
    game.move(moves[random.nextInt(moves.length)]);
  }
  return game;
}

void main() {
  group('board setup', () {
    test('back ranks are mirrored and shovers fill the second ranks', () {
      final game = ShoveGame(white, black);
      for (var y = 0; y < ShoveGame.totalNumberOfColumns; y++) {
        final whiteBack = game.pieces[game.getSquareByXY(7, y)!.pieceId]!;
        final blackBack = game.pieces[game.getSquareByXY(0, y)!.pieceId]!;
        expect(whiteBack.owner, white);
        expect(blackBack.owner, black);
        expect(whiteBack.pieceType, blackBack.pieceType);
        expect(
          game.pieces[game.getSquareByXY(6, y)!.pieceId]!.pieceType,
          PieceType.shover,
        );
        expect(
          game.pieces[game.getSquareByXY(1, y)!.pieceId]!.pieceType,
          PieceType.shover,
        );
      }
      for (var x = 2; x <= 5; x++) {
        for (var y = 0; y < ShoveGame.totalNumberOfColumns; y++) {
          expect(game.getSquareByXY(x, y)!.pieceId, isNull);
        }
      }
    });

    test('player 1 starts and moves towards row 0', () {
      final game = ShoveGame(white, black);
      expect(game.currentPlayersTurn, white);
      expect(game.forwardDirectionOf(white), -1);
      expect(game.forwardDirectionOf(black), 1);
      expect(game.goalSquaresOf(white).every((s) => s.x == 0), isTrue);
      expect(game.goalSquaresOf(black).every((s) => s.x == 7), isTrue);
      expect(
        game.getSquaresDistanceToGoal(white, game.getSquareByXY(6, 0)!),
        6,
      );
      expect(
        game.getSquaresDistanceToGoal(black, game.getSquareByXY(6, 0)!),
        1,
      );
      expect(game.getOpponent(white), black);
      expect(game.getOpponent(black), white);
    });

    test('the opening position has legal moves and is not over', () {
      final game = ShoveGame(white, black);
      expect(game.getAllLegalMoves(), isNotEmpty);
      expect(game.hasAnyLegalMove(), isTrue);
      expect(game.checkIfGameIsOver().isOver, isFalse);
    });

    test('squares outside the board do not exist', () {
      final game = ShoveGame(white, black);
      for (final (x, y) in [(-1, 0), (0, -1), (8, 0), (0, 8)]) {
        expect(game.isOutOfBounds(x, y), isTrue);
        expect(game.getSquareByXY(x, y), isNull);
      }
      expect(game.getAllNeighborSquares(game.getSquareByXY(0, 0)!).length, 3);
      expect(game.getAllNeighborSquares(game.getSquareByXY(3, 3)!).length, 8);
    });

    test('pieces get unique ids and textures matching their colour', () {
      final game = ShoveGame(white, black);
      expect(game.pieces.keys.toSet().length, game.pieces.length);
      for (final piece in game.pieces.values) {
        expect(piece.texture, isNotNull);
        final isInverted = piece.texture!.name.startsWith('inv');
        expect(isInverted, !piece.owner.isWhite, reason: '${piece.texture}');
      }
    });
  });

  group('shover', () {
    test('moves one step forward or sideways only', () {
      final game = sparseGame();
      place(game, 4, 4, ShovePiece.shover(white));

      final targets = game
          .getLegalMovesFrom(game.getSquareByXY(4, 4)!)
          .map((m) => (m.newSquare.x, m.newSquare.y))
          .toSet();

      expect(targets, {(3, 4), (4, 3), (4, 5)});
    });

    test('shoving stuns the enemy and pushes it one square', () {
      final game = sparseGame();
      place(game, 4, 4, ShovePiece.shover(white));
      final victim = place(game, 3, 4, ShovePiece.thrower(black));

      final move = moveOf(game, (4, 4), (3, 4));
      expect(game.move(move), AudioAssets.bonk);

      expect(game.getSquareByXY(2, 4)!.pieceId, victim.id);
      expect(victim.isIncapacitated, isTrue);
      expect(move.shovedPiece, victim);
      expect(move.shovedToSquare, game.getSquareByXY(2, 4));
      expect(move.eliminatedPiece, isFalse);
    });

    test('sideways shoves push sideways', () {
      final game = sparseGame();
      place(game, 4, 4, ShovePiece.shover(white));
      final victim = place(game, 4, 5, ShovePiece.leaper(black));

      game.move(moveOf(game, (4, 4), (4, 5)));

      expect(game.getSquareByXY(4, 6)!.pieceId, victim.id);
      expect(game.getSquareByXY(4, 5)!.pieceId, isNotNull);
    });

    test('cannot shove blockers, friends, or into another piece', () {
      final game = sparseGame();
      place(game, 4, 4, ShovePiece.shover(white));
      place(game, 3, 4, ShovePiece.blocker(black));
      place(game, 4, 3, ShovePiece.thrower(white));
      place(game, 4, 5, ShovePiece.thrower(black));
      place(game, 4, 6, ShovePiece.thrower(black));

      expect(game.getLegalMovesFrom(game.getSquareByXY(4, 4)!), isEmpty);
    });

    test('shoving off the board eliminates and plays a scream', () {
      final game = sparseGame();
      place(game, 4, 1, ShovePiece.shover(white));
      final victim = place(game, 4, 0, ShovePiece.thrower(black));

      expect(game.move(moveOf(game, (4, 1), (4, 0))), AudioAssets.scream);
      expect(game.pieces.containsKey(victim.id), isFalse);
    });
  });

  group('blocker', () {
    test('moves one or two squares straight without jumping', () {
      final game = sparseGame();
      place(game, 4, 4, ShovePiece.blocker(white));
      place(game, 3, 4, ShovePiece.thrower(black));

      final targets = game
          .getLegalMovesFrom(game.getSquareByXY(4, 4)!)
          .map((m) => (m.newSquare.x, m.newSquare.y))
          .toSet();

      expect(targets, {(5, 4), (6, 4), (4, 3), (4, 2), (4, 5), (4, 6)});
    });
  });

  group('thrower', () {
    test('moves one step in any direction onto empty squares', () {
      final game = sparseGame();
      place(game, 4, 4, ShovePiece.thrower(white));
      place(game, 3, 3, ShovePiece.blocker(black));

      final targets = game
          .getLegalMovesFrom(game.getSquareByXY(4, 4)!)
          .where((m) => m.shoveGameMoveType == ShoveGameMoveType.move)
          .map((m) => (m.newSquare.x, m.newSquare.y))
          .toSet();

      expect(targets.length, 7);
      expect(targets.contains((3, 3)), isFalse);
    });

    test('throws an adjacent enemy next to itself and stuns it', () {
      final game = sparseGame();
      place(game, 4, 4, ShovePiece.thrower(white));
      final victim = place(game, 4, 5, ShovePiece.shover(black));

      final throws = game.getLegalMovesFrom(game.getSquareByXY(4, 5)!);
      expect(throws.length, 7, reason: 'every empty square around thrower');
      for (final t in throws) {
        expect(t.shoveGameMoveType, ShoveGameMoveType.thrown);
        expect((t.newSquare.x - 4).abs() <= 1, isTrue);
        expect((t.newSquare.y - 4).abs() <= 1, isTrue);
      }

      final move = moveOf(game, (4, 5), (3, 3), thrower: (4, 4));
      expect(game.move(move), AudioAssets.throwSound);
      expect(game.getSquareByXY(3, 3)!.pieceId, victim.id);
      expect(game.getSquareByXY(4, 5)!.pieceId, isNull);
      expect(victim.isIncapacitated, isTrue);
      expect(move.thrownPiece, victim);
    });

    test('cannot throw blockers, friends, or with a stunned thrower', () {
      final game = sparseGame();
      final thrower = place(game, 4, 4, ShovePiece.thrower(white));
      place(game, 4, 5, ShovePiece.blocker(black));
      place(game, 3, 4, ShovePiece.leaper(white));
      final enemy = place(game, 5, 3, ShovePiece.leaper(black));

      expect(game.getLegalMovesFrom(game.getSquareByXY(4, 5)!), isEmpty);
      expect(
        game.validateMove(moveOf(game, (3, 4), (3, 3), thrower: (4, 4))),
        isFalse,
      );
      expect(game.getLegalMovesFrom(game.getSquareByXY(5, 3)!), isNotEmpty);

      thrower.isIncapacitated = true;
      expect(game.getLegalMovesFrom(game.getSquareByXY(5, 3)!), isEmpty);
      thrower.isIncapacitated = false;
      enemy.isIncapacitated = true;
      expect(game.getLegalMovesFrom(game.getSquareByXY(5, 3)!), isEmpty);
    });
  });

  group('leaper', () {
    test('cannot land on pieces or make knight-like jumps', () {
      final game = sparseGame();
      place(game, 4, 4, ShovePiece.leaper(white));
      place(game, 3, 4, ShovePiece.thrower(black));
      place(game, 3, 5, ShovePiece.thrower(white));

      expect(game.validateMove(moveOf(game, (4, 4), (3, 4))), isFalse);
      expect(game.validateMove(moveOf(game, (4, 4), (2, 5))), isFalse);
      expect(game.validateMove(moveOf(game, (4, 4), (2, 4))), isTrue);
    });
  });

  group('turns and stuns', () {
    test('only the current player can move and turns alternate', () {
      final game = ShoveGame(white, black);
      expect(game.validateMove(moveOf(game, (1, 0), (2, 0))), isFalse);
      expect(game.getLegalMovesFrom(game.getSquareByXY(1, 0)!), isEmpty);

      game.move(moveOf(game, (6, 0), (5, 0)));
      expect(game.currentPlayersTurn, black);
      expect(game.validateMove(moveOf(game, (5, 0), (4, 0))), isFalse);
      expect(game.validateMove(moveOf(game, (1, 0), (2, 0))), isTrue);
    });

    test('a stunned piece skips exactly one turn', () {
      final game = sparseGame();
      place(game, 4, 4, ShovePiece.shover(white));
      final victim = place(game, 3, 4, ShovePiece.shover(black));

      game.move(moveOf(game, (4, 4), (3, 4)));
      expect(victim.isIncapacitated, isTrue);
      expect(game.getLegalMovesFrom(game.getSquareByXY(2, 4)!), isEmpty);

      game.move(moveOf(game, (1, 7), (2, 7)));
      expect(victim.isIncapacitated, isFalse);

      game.move(moveOf(game, (6, 7), (5, 7)));
      expect(game.getLegalMovesFrom(game.getSquareByXY(2, 4)!), isNotEmpty);
    });

    test('moving to the same square or from an empty square is illegal', () {
      final game = ShoveGame(white, black);
      expect(game.validateMove(moveOf(game, (6, 0), (6, 0))), isFalse);
      expect(game.validateMove(moveOf(game, (4, 0), (3, 0))), isFalse);
    });

    test('no move is legal once the game is over', () {
      final game = sparseGame();
      place(game, 1, 0, ShovePiece.shover(white));
      game.move(moveOf(game, (1, 0), (0, 0)));

      expect(game.isGameOver, isTrue);
      expect(game.getAllLegalMoves(), isEmpty);
      expect(game.validateMove(moveOf(game, (1, 7), (2, 7))), isFalse);
    });

    test('black wins by reaching row 7', () {
      final game = sparseGame();
      place(game, 6, 0, ShovePiece.shover(black));
      game.currentPlayersTurn = black;

      game.move(moveOf(game, (6, 0), (7, 0)));

      expect(game.gameOverState?.winner, black);
      expect(game.gameOverReason, GameOverReason.reachedGoal);
    });

    test('repeating the same moves ends in a draw, undo revives the game', () {
      final game = repetitionGame(white, black);
      playUntilOneMoveBeforeRepetition(game);
      expect(game.isGameOver, isFalse);

      game.move(moveOf(game, (2, 3), (2, 4)));

      expect(game.isGameOver, isTrue);
      expect(game.isDraw, isTrue);
      expect(game.gameOverReason, GameOverReason.repetition);

      game.undoLastMove();
      expect(game.isGameOver, isFalse);
      expect(game.gameOverReason, isNull);
    });

    test('undoing every move restores the opening position', () {
      final start = ShoveGame(white, black).positionKey;
      final game = playRandomly(40);

      while (game.allMadeMoves.isNotEmpty) {
        game.undoLastMove();
      }

      expect(game.positionKey, start);
      expect(game.pieces.length, 32);
      expect(game.incapacitatedPieces, isEmpty);
      expect(game.currentPlayersTurn, white);
    });

    test('undo with no moves made does nothing', () {
      final game = ShoveGame(white, black);
      final key = game.positionKey;
      game.undoLastMove();
      expect(game.positionKey, key);
    });
  });

  group('position key', () {
    test('depends on side to move, stuns and piece placement', () {
      final game = ShoveGame(white, black);
      final key = game.positionKey;

      game.currentPlayersTurn = black;
      expect(game.positionKey, isNot(key));
      game.currentPlayersTurn = white;
      expect(game.positionKey, key);

      final piece = game.pieces[game.getSquareByXY(6, 0)!.pieceId]!;
      piece.isIncapacitated = true;
      expect(game.positionKey, isNot(key));
      piece.isIncapacitated = false;

      game.move(moveOf(game, (6, 0), (5, 0)));
      expect(game.positionKey, isNot(key));
      game.undoLastMove();
      expect(game.positionKey, key);
    });

    test('stays below 2^53 so it is exact on the web', () {
      final game = playRandomly(30, seed: 11);
      expect(game.positionKey, lessThan(1 << 53));
      expect(game.positionKey, greaterThanOrEqualTo(0));
    });
  });

  group('serialization', () {
    ShoveGame roundTrip(ShoveGame game) => ShoveGame.fromDto(
      ShoveGameStateDto.fromJson(
        jsonDecode(jsonEncode(ShoveGameStateDto.fromGame(game).toJson())),
      ),
    );

    test('a game survives a JSON round trip', () {
      final game = playRandomly(25);
      final restored = roundTrip(game);

      expect(restored.positionKey, game.positionKey);
      expect(restored.currentPlayersTurn, game.currentPlayersTurn);
      expect(restored.pieces.length, game.pieces.length);
      expect(restored.allMadeMoves.length, game.allMadeMoves.length);
      expect(
        restored.incapacitatedPieces.map((p) => p.id).toSet(),
        game.incapacitatedPieces.map((p) => p.id).toSet(),
      );
      String describe(ShoveGameMove m) =>
          '${m.oldSquare.x}${m.oldSquare.y}${m.newSquare.x}${m.newSquare.y}'
          '${m.throwerSquare?.x}${m.throwerSquare?.y}';
      expect(
        restored.getAllLegalMoves().map(describe).toSet(),
        game.getAllLegalMoves().map(describe).toSet(),
      );
    });

    test('restored pieces share the restored player instances', () {
      final restored = roundTrip(playRandomly(5));
      for (final piece in restored.pieces.values) {
        expect(
          identical(piece.owner, restored.player1) ||
              identical(piece.owner, restored.player2),
          isTrue,
        );
      }
      expect(
        identical(restored.currentPlayersTurn, restored.player1) ||
            identical(restored.currentPlayersTurn, restored.player2),
        isTrue,
      );
    });

    test('a finished game keeps its winner', () {
      final game = sparseGame();
      place(game, 1, 0, ShovePiece.shover(white));
      game.move(moveOf(game, (1, 0), (0, 0)));

      final restored = roundTrip(game);
      expect(restored.isGameOver, isTrue);
      expect(restored.gameOverState?.winner, white);
    });

    test('player types survive serialization', () {
      final players = <IPlayer>[
        ShovePlayer('human', true),
        MinMaxAi('minmax', false),
        RandomAi('random', true),
      ];
      for (final player in players) {
        final dto = ShovePlayerDto.fromJson(
          jsonDecode(jsonEncode(ShovePlayerDto.fromPlayer(player).toJson())),
        );
        final restored = IPlayer.fromDto(dto);
        expect(restored.runtimeType, player.runtimeType);
        expect(restored, player);
      }
    });

    test('moves survive serialization including the thrower', () {
      final game = sparseGame();
      place(game, 4, 4, ShovePiece.thrower(white));
      place(game, 4, 5, ShovePiece.shover(black));
      final move = moveOf(game, (4, 5), (3, 3), thrower: (4, 4));

      final restored = ShoveGameMove.fromDto(
        ShoveGameMoveDto.fromJson(
          jsonDecode(jsonEncode(ShoveGameMoveDto.fromGameMove(move).toJson())),
        ),
      );

      expect(restored, move);
      expect(restored.shoveGameMoveType, ShoveGameMoveType.thrown);
      expect(restored.throwerSquare?.x, 4);
      expect(restored.throwerSquare?.y, 4);
    });

    test('copy is independent of the original', () {
      final game = playRandomly(10);
      final key = game.positionKey;
      final copy = game.copy();

      expect(copy.positionKey, key);
      final moves = copy.getAllLegalMoves();
      copy.move(moves.first);

      expect(game.positionKey, key);
      expect(game.allMadeMoves.length, 10);
      expect(copy.allMadeMoves.length, 11);
    });

    test('copy keeps the game over state', () {
      final game = repetitionGame(white, black);
      playUntilOneMoveBeforeRepetition(game);
      game.move(moveOf(game, (2, 3), (2, 4)));

      final copy = game.copy();
      expect(copy.isDraw, isTrue);
      expect(copy.gameOverReason, GameOverReason.repetition);
    });
  });

  group('equality', () {
    test('players are equal by name and colour', () {
      expect(ShovePlayer('a', true), ShovePlayer('a', true));
      expect(ShovePlayer('a', true), isNot(ShovePlayer('a', false)));
      expect(ShovePlayer('a', true), isNot(ShovePlayer('b', true)));
    });

    test('moves are equal by squares, player and type', () {
      final game = sparseGame();
      place(game, 4, 4, ShovePiece.thrower(white));
      place(game, 4, 5, ShovePiece.shover(black));

      expect(moveOf(game, (4, 4), (3, 4)), moveOf(game, (4, 4), (3, 4)));
      expect(
        moveOf(game, (4, 4), (3, 4)).hashCode,
        moveOf(game, (4, 4), (3, 4)).hashCode,
      );
      expect(
        moveOf(game, (4, 5), (3, 3)),
        isNot(moveOf(game, (4, 5), (3, 3), thrower: (4, 4))),
      );
    });
  });
}
