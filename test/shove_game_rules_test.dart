import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_player.dart';

final white = ShovePlayer('white', true);
final black = ShovePlayer('black', false);

ShoveGame emptyGame() {
  final game = ShoveGame(white, black);
  for (final square in game.board.values) {
    square.pieceId = null;
  }
  game.pieces.clear();
  return game;
}

ShovePiece place(ShoveGame game, int x, int y, ShovePiece piece) {
  game.getSquareByXY(x, y)!.pieceId = piece.id;
  game.pieces[piece.id] = piece;
  return piece;
}

ShoveGameMove moveOf(
  ShoveGame game,
  (int, int) from,
  (int, int) to, {
  (int, int)? thrower,
}) => ShoveGameMove(
  game.getSquareByXY(from.$1, from.$2)!,
  game.getSquareByXY(to.$1, to.$2)!,
  game.currentPlayersTurn,
  throwerSquare: thrower == null
      ? null
      : game.getSquareByXY(thrower.$1, thrower.$2),
);

/// Reference implementation: every square x every target x every thrower.
Set<String> bruteForceLegalMoves(ShoveGame game) {
  final result = <String>{};
  for (final from in game.board.values) {
    if (from.pieceId == null) continue;
    for (final to in game.board.values) {
      final candidates = [
        ShoveGameMove(from, to, game.currentPlayersTurn),
        for (final n in game.getAllNeighborSquares(from))
          ShoveGameMove(from, to, game.currentPlayersTurn, throwerSquare: n),
      ];
      for (final m in candidates) {
        if (game.validateMove(m)) result.add(describe(m));
      }
    }
  }
  return result;
}

String describe(ShoveGameMove m) =>
    '${m.oldSquare.x},${m.oldSquare.y}->${m.newSquare.x},${m.newSquare.y}'
    ' t:${m.throwerSquare?.x},${m.throwerSquare?.y}';

void main() {
  test('initial setup has 16 pieces per side, all on the board', () {
    final game = ShoveGame(white, black);
    expect(game.pieces.length, 32);
    final onBoard = game.board.values
        .where((s) => s.pieceId != null)
        .map((s) => s.pieceId);
    expect(onBoard.toSet(), game.pieces.keys.toSet());
    expect(game.player1GoalShoveSquares.length, ShoveGame.totalNumberOfColumns);
  });

  test('reaching the goal on the last column wins', () {
    final game = emptyGame();
    place(game, 1, 7, ShovePiece.shover(white));
    place(game, 4, 4, ShovePiece.shover(black));

    game.move(moveOf(game, (1, 7), (0, 7)));

    expect(game.gameOverState?.winner, white);
    expect(game.gameOverReason, GameOverReason.reachedGoal);
  });

  test('shoving a piece off the board eliminates it and undo restores it', () {
    final game = emptyGame();
    place(game, 3, 1, ShovePiece.shover(white));
    final victim = place(game, 3, 0, ShovePiece.thrower(black));
    place(game, 1, 5, ShovePiece.shover(black));

    final move = moveOf(game, (3, 1), (3, 0));
    expect(game.validateMove(move), isTrue);
    game.move(move);

    expect(game.pieces.containsKey(victim.id), isFalse);
    expect(move.eliminatedPiece, isTrue);

    game.undoLastMove();
    expect(game.pieces.containsKey(victim.id), isTrue);
    expect(game.getSquareByXY(3, 0)!.pieceId, victim.id);
    expect(victim.isIncapacitated, isFalse);
    expect(game.currentPlayersTurn, white);
  });

  test('leaper leaps diagonally, stuns enemies but not friends', () {
    final game = emptyGame();
    place(game, 4, 4, ShovePiece.leaper(white));
    final enemy = place(game, 3, 3, ShovePiece.thrower(black));
    final friend = place(game, 3, 5, ShovePiece.thrower(white));
    place(game, 6, 0, ShovePiece.shover(white));
    place(game, 1, 0, ShovePiece.shover(black));

    final leapEnemy = moveOf(game, (4, 4), (2, 2));
    expect(game.validateMove(leapEnemy), isTrue);
    expect(game.validateMove(moveOf(game, (4, 4), (2, 6))), isTrue);
    expect(
      game.validateMove(moveOf(game, (4, 4), (2, 4))),
      isFalse,
      reason: 'nothing to leap over',
    );

    game.move(leapEnemy);
    expect(enemy.isIncapacitated, isTrue);
    expect(friend.isIncapacitated, isFalse);
    expect(
      game.getLegalMovesFrom(game.getSquareByXY(3, 3)!),
      isEmpty,
      reason: 'stunned pieces cannot move',
    );
  });

  test('leaper single step does not stun anything', () {
    final game = emptyGame();
    final leaper = place(game, 4, 4, ShovePiece.leaper(white));
    place(game, 6, 0, ShovePiece.shover(white));
    place(game, 1, 0, ShovePiece.shover(black));

    game.move(moveOf(game, (4, 4), (3, 3)));
    expect(leaper.isIncapacitated, isFalse);
    expect(game.pieces.values.any((p) => p.isIncapacitated), isFalse);
  });

  test('throws must land on the board', () {
    final game = emptyGame();
    place(game, 0, 1, ShovePiece.thrower(white));
    place(game, 1, 1, ShovePiece.shover(black));
    place(game, 6, 0, ShovePiece.shover(white));

    final throws = game.getLegalMovesFrom(game.getSquareByXY(1, 1)!);
    expect(throws, isNotEmpty);
    for (final t in throws) {
      expect(game.isOutOfBounds(t.newSquare.x, t.newSquare.y), isFalse);
    }
  });

  test('pieces next to their own blocker cannot be thrown', () {
    final game = emptyGame();
    place(game, 3, 3, ShovePiece.thrower(white));
    place(game, 2, 3, ShovePiece.shover(black));
    place(game, 1, 3, ShovePiece.blocker(black));
    place(game, 6, 0, ShovePiece.shover(white));

    expect(game.getLegalMovesFrom(game.getSquareByXY(2, 3)!), isEmpty);
  });

  test('losing the last shover loses the game', () {
    final game = emptyGame();
    place(game, 3, 1, ShovePiece.shover(white));
    place(game, 3, 0, ShovePiece.shover(black));
    place(game, 0, 7, ShovePiece.thrower(black));

    game.move(moveOf(game, (3, 1), (3, 0)));

    expect(game.gameOverState?.winner, white);
    expect(game.gameOverReason, GameOverReason.noShoversLeft);

    game.undoLastMove();
    expect(game.isGameOver, isFalse);
    expect(game.gameOverReason, isNull);
  });

  test('a player without legal moves loses', () {
    final game = emptyGame();
    place(game, 3, 7, ShovePiece.shover(white));
    // Black's only piece is a shover that is about to be boxed in by blockers
    place(game, 5, 0, ShovePiece.shover(black));
    place(game, 6, 0, ShovePiece.blocker(white));
    place(game, 5, 3, ShovePiece.blocker(white));

    game.move(moveOf(game, (5, 3), (5, 1)));

    expect(game.gameOverReason, GameOverReason.noLegalMoves);
    expect(game.gameOverState?.winner, white);
  });

  test('undo restores stun state of every piece', () {
    final game = ShoveGame(white, black);
    final random = Random(1);
    for (var i = 0; i < 60 && !game.isGameOver; i++) {
      final before = {
        for (final p in game.pieces.values) p.id: p.isIncapacitated,
      };
      final boardBefore = {
        for (final s in game.board.values) (s.x, s.y): s.pieceId,
      };
      final moves = game.getAllLegalMoves();
      game.move(moves[random.nextInt(moves.length)]);
      game.undoLastMove();
      expect({
        for (final p in game.pieces.values) p.id: p.isIncapacitated,
      }, before);
      expect({
        for (final s in game.board.values) (s.x, s.y): s.pieceId,
      }, boardBefore);
      game.move(moves[random.nextInt(moves.length)]);
    }
  });

  test('fast legal move generator matches brute force', () {
    final game = ShoveGame(white, black);
    final random = Random(7);
    for (var i = 0; i < 40 && !game.isGameOver; i++) {
      final fast = game.getAllLegalMoves().map(describe).toSet();
      expect(fast, bruteForceLegalMoves(game));
      final moves = game.getAllLegalMoves();
      game.move(moves[random.nextInt(moves.length)]);
    }
  });

  test('every piece type has a positive value', () {
    for (final type in PieceType.values) {
      expect(type.pieceValue, greaterThan(0));
    }
  });
}
