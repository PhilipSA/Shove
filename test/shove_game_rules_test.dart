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
        for (final n in game.board.values)
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

  test('hasLegalMovesFrom agrees with getLegalMovesFrom', () {
    final game = ShoveGame(white, black);
    final random = Random(3);
    for (var i = 0; i < 40 && !game.isGameOver; i++) {
      for (final square in game.squares) {
        expect(
          game.hasLegalMovesFrom(square),
          game.getLegalMovesFrom(square).isNotEmpty,
        );
      }
      final moves = game.getAllLegalMoves();
      game.move(moves[random.nextInt(moves.length)]);
    }
  });

  test('getLegalAttackerMoves are the shover and charger moves', () {
    final game = ShoveGame(white, black);
    final random = Random(5);
    for (var i = 0; i < 40 && !game.isGameOver; i++) {
      final moves = game.getAllLegalMoves();
      expect(
        game.getLegalAttackerMoves().map(describe),
        moves
            .where(
              (m) =>
                  m.throwerSquare == null &&
                  const [
                    PieceType.shover,
                    PieceType.charger,
                  ].contains(game.pieceOn(m.oldSquare)?.pieceType) &&
                  game.pieceOn(m.oldSquare)?.owner == game.currentPlayersTurn,
            )
            .map(describe),
      );
      game.move(moves[random.nextInt(moves.length)]);
    }
  });

  test('a copy does not follow the squares of the original game', () {
    final game = ShoveGame(white, black);
    game.move(game.getAllLegalMoves().first);

    final copy = game.copy();

    expect(copy.allMadeMoves.single, game.allMadeMoves.single);
    expect(
      identical(
        copy.allMadeMoves.single.oldSquare,
        game.allMadeMoves.single.oldSquare,
      ),
      isFalse,
    );
    expect(copy.getSquareByXY(0, 0), isNot(same(game.getSquareByXY(0, 0))));
  });

  test('charger runs as far as it can in each straight direction', () {
    final game = emptyGame();
    place(game, 4, 4, ShovePiece.charger(white));
    place(game, 6, 1, ShovePiece.shover(white));
    place(game, 1, 1, ShovePiece.shover(black));

    expect(
      game.getLegalMovesFrom(game.getSquareByXY(4, 4)!).map(describe).toSet(),
      {
        describe(moveOf(game, (4, 4), (0, 4))),
        describe(moveOf(game, (4, 4), (7, 4))),
        describe(moveOf(game, (4, 4), (4, 0))),
        describe(moveOf(game, (4, 4), (4, 7))),
      },
    );
    expect(game.validateMove(moveOf(game, (4, 4), (2, 4))), isFalse);
    expect(game.validateMove(moveOf(game, (4, 4), (2, 2))), isFalse);
  });

  test('charger stops in front of friends, blockers and walls', () {
    final game = emptyGame();
    place(game, 4, 4, ShovePiece.charger(white));
    place(game, 4, 6, ShovePiece.thrower(white));
    place(game, 2, 4, ShovePiece.blocker(black));
    place(game, 6, 1, ShovePiece.shover(white));
    place(game, 1, 1, ShovePiece.shover(black));

    final ends = game
        .getLegalMovesFrom(game.getSquareByXY(4, 4)!)
        .map((m) => (m.newSquare.x, m.newSquare.y))
        .toSet();
    expect(ends, {(3, 4), (7, 4), (4, 0), (4, 5)});
  });

  test('charger shoves an enemy off the board when nothing stops it', () {
    final game = emptyGame();
    final charger = place(game, 4, 1, ShovePiece.charger(white));
    final victim = place(game, 4, 5, ShovePiece.leaper(black));
    place(game, 6, 1, ShovePiece.shover(white));
    place(game, 1, 1, ShovePiece.shover(black));

    final charge = moveOf(game, (4, 1), (4, 5));
    expect(game.validateMove(charge), isTrue);
    game.move(charge);

    expect(charge.eliminatedPiece, isTrue);
    expect(game.pieces.containsKey(victim.id), isFalse);
    expect(game.getSquareByXY(4, 5)!.pieceId, charger.id);
    expect(game.getSquareByXY(4, 1)!.pieceId, isNull);

    game.undoLastMove();
    expect(game.getSquareByXY(4, 5)!.pieceId, victim.id);
    expect(game.getSquareByXY(4, 1)!.pieceId, charger.id);
    expect(game.pieces.containsKey(victim.id), isTrue);
    expect(victim.isIncapacitated, isFalse);
  });

  test('charger shoves an enemy as far back as it goes and stuns it', () {
    final game = emptyGame();
    place(game, 4, 1, ShovePiece.charger(white));
    final victim = place(game, 4, 3, ShovePiece.leaper(black));
    place(game, 4, 7, ShovePiece.thrower(black));
    place(game, 6, 1, ShovePiece.shover(white));
    place(game, 1, 1, ShovePiece.shover(black));

    final charge = moveOf(game, (4, 1), (4, 3));
    game.move(charge);

    expect(game.getSquareByXY(4, 6)!.pieceId, victim.id);
    expect(
      game.getSquareByXY(4, 3)!.pieceId,
      game.pieces.values.firstWhere((p) => p.pieceType == PieceType.charger).id,
    );
    expect(victim.isIncapacitated, isTrue);
    expect(charge.eliminatedPiece, isFalse);

    game.undoLastMove();
    expect(game.getSquareByXY(4, 3)!.pieceId, victim.id);
    expect(game.getSquareByXY(4, 6)!.pieceId, isNull);
    expect(victim.isIncapacitated, isFalse);
  });

  test('charger cannot shove blockers or enemies with no room behind them', () {
    final game = emptyGame();
    place(game, 4, 1, ShovePiece.charger(white));
    place(game, 4, 4, ShovePiece.leaper(black));
    place(game, 4, 5, ShovePiece.thrower(black));
    place(game, 2, 1, ShovePiece.blocker(black));
    place(game, 6, 1, ShovePiece.shover(white));
    place(game, 1, 6, ShovePiece.shover(black));

    final ends = game
        .getLegalMovesFrom(game.getSquareByXY(4, 1)!)
        .map((m) => (m.newSquare.x, m.newSquare.y))
        .toSet();
    expect(ends, {(3, 1), (5, 1), (4, 0), (4, 3)});
  });

  test('a charger next to an enemy it cannot shove has no move that way', () {
    final game = emptyGame();
    place(game, 4, 1, ShovePiece.charger(white));
    place(game, 4, 2, ShovePiece.leaper(black));
    place(game, 4, 3, ShovePiece.thrower(black));
    place(game, 6, 1, ShovePiece.shover(white));
    place(game, 1, 6, ShovePiece.shover(black));

    expect(game.validateMove(moveOf(game, (4, 1), (4, 2))), isFalse);
    expect(
      game
          .getLegalMovesFrom(game.getSquareByXY(4, 1)!)
          .any((m) => m.newSquare.y > 1),
      isFalse,
    );
  });

  test('a charger that shoves an enemy is stunned for its next turn', () {
    final game = emptyGame();
    final charger = place(game, 4, 1, ShovePiece.charger(white));
    final victim = place(game, 4, 3, ShovePiece.leaper(black));
    place(game, 4, 7, ShovePiece.thrower(black));
    place(game, 6, 1, ShovePiece.shover(white));
    place(game, 1, 1, ShovePiece.shover(black));

    game.move(moveOf(game, (4, 1), (4, 3)));
    expect(charger.isIncapacitated, isTrue);
    expect(victim.isIncapacitated, isTrue);

    game.move(moveOf(game, (1, 1), (2, 1)));
    expect(game.getLegalMovesFrom(game.getSquareByXY(4, 3)!), isEmpty);
    expect(charger.isIncapacitated, isTrue);

    game.move(moveOf(game, (6, 1), (5, 1)));
    expect(charger.isIncapacitated, isFalse);

    game.undoLastMove();
    game.undoLastMove();
    game.undoLastMove();
    expect(charger.isIncapacitated, isFalse);
    expect(victim.isIncapacitated, isFalse);
  });

  test('a charger that shoves nobody is not stunned', () {
    final game = emptyGame();
    final charger = place(game, 4, 4, ShovePiece.charger(white));
    place(game, 6, 1, ShovePiece.shover(white));
    place(game, 1, 1, ShovePiece.shover(black));

    game.move(moveOf(game, (4, 4), (0, 4)));

    expect(charger.isIncapacitated, isFalse);
  });

  test('hook pulls an enemy in a clear line next to itself and stuns it', () {
    final game = emptyGame();
    final hook = place(game, 5, 4, ShovePiece.hook(white));
    final enemy = place(game, 2, 4, ShovePiece.leaper(black));
    place(game, 6, 0, ShovePiece.shover(white));
    place(game, 1, 0, ShovePiece.shover(black));

    final pull = moveOf(game, (2, 4), (4, 4), thrower: (5, 4));
    expect(game.validateMove(pull), isTrue);
    expect(game.getLegalMovesFrom(game.getSquareByXY(2, 4)!).map(describe), [
      describe(pull),
    ]);

    game.move(pull);
    expect(game.getSquareByXY(4, 4)!.pieceId, enemy.id);
    expect(game.getSquareByXY(2, 4)!.pieceId, isNull);
    expect(game.getSquareByXY(5, 4)!.pieceId, hook.id);
    expect(enemy.isIncapacitated, isTrue);

    game.undoLastMove();
    expect(game.getSquareByXY(2, 4)!.pieceId, enemy.id);
    expect(game.getSquareByXY(4, 4)!.pieceId, isNull);
    expect(enemy.isIncapacitated, isFalse);
  });

  test('hook pulls friends without stunning them', () {
    final game = emptyGame();
    place(game, 3, 4, ShovePiece.hook(white));
    final friend = place(game, 6, 4, ShovePiece.shover(white));
    place(game, 1, 0, ShovePiece.shover(black));

    final pull = moveOf(game, (6, 4), (4, 4), thrower: (3, 4));
    expect(game.validateMove(pull), isTrue);
    expect(
      game.getLegalMovesFrom(game.getSquareByXY(6, 4)!).map(describe),
      contains(describe(pull)),
    );

    game.move(pull);
    expect(game.getSquareByXY(4, 4)!.pieceId, friend.id);
    expect(friend.isIncapacitated, isFalse);

    game.undoLastMove();
    expect(game.getSquareByXY(6, 4)!.pieceId, friend.id);
    expect(friend.isIncapacitated, isFalse);
  });

  test('hook can pull a stunned friend out of the way', () {
    final game = emptyGame();
    place(game, 3, 4, ShovePiece.hook(white));
    final friend = place(game, 5, 4, ShovePiece.shover(white));
    friend.isIncapacitated = true;
    place(game, 1, 0, ShovePiece.shover(black));

    final pull = moveOf(game, (5, 4), (4, 4), thrower: (3, 4));
    expect(game.validateMove(pull), isTrue);
    expect(game.validateMove(moveOf(game, (5, 4), (4, 4))), isFalse);

    game.move(pull);
    expect(game.getSquareByXY(4, 4)!.pieceId, friend.id);
  });

  test('hook cannot pull through pieces, from too far or diagonally', () {
    final game = emptyGame();
    place(game, 5, 4, ShovePiece.hook(white));
    place(game, 6, 0, ShovePiece.shover(white));
    place(game, 1, 0, ShovePiece.shover(black));
    place(game, 1, 4, ShovePiece.leaper(black));
    place(game, 3, 2, ShovePiece.leaper(black));
    place(game, 4, 4, ShovePiece.leaper(black));

    expect(game.getLegalMovesFrom(game.getSquareByXY(1, 4)!), isEmpty);
    expect(game.getLegalMovesFrom(game.getSquareByXY(3, 2)!), isEmpty);
    expect(
      game.getLegalMovesFrom(game.getSquareByXY(4, 4)!),
      isEmpty,
      reason: 'already adjacent',
    );

    final adjacent = game.pieceOn(game.getSquareByXY(4, 4)!)!;
    game.getSquareByXY(4, 4)!.pieceId = null;
    game.pieces.remove(adjacent.id);
    place(game, 2, 4, ShovePiece.leaper(black));
    expect(
      game.getLegalMovesFrom(game.getSquareByXY(2, 4)!),
      hasLength(1),
      reason: 'three squares away in a clear line',
    );

    place(game, 3, 4, ShovePiece.blocker(white));
    expect(
      game.getLegalMovesFrom(game.getSquareByXY(2, 4)!),
      isEmpty,
      reason: 'a piece is in the way',
    );
  });

  test('hook cannot pull enemy blockers, guarded or stunned enemies', () {
    final game = emptyGame();
    place(game, 5, 4, ShovePiece.hook(white));
    place(game, 6, 0, ShovePiece.shover(white));
    place(game, 1, 0, ShovePiece.shover(black));
    place(game, 3, 4, ShovePiece.blocker(black));
    place(game, 5, 1, ShovePiece.leaper(black));
    place(game, 4, 1, ShovePiece.blocker(black));
    final stunned = place(game, 5, 7, ShovePiece.leaper(black));
    stunned.isIncapacitated = true;

    expect(game.getLegalMovesFrom(game.getSquareByXY(3, 4)!), isEmpty);
    expect(game.getLegalMovesFrom(game.getSquareByXY(5, 1)!), isEmpty);
    expect(game.getLegalMovesFrom(game.getSquareByXY(5, 7)!), isEmpty);
  });

  test('hook moves one step horizontally or vertically only', () {
    final game = emptyGame();
    place(game, 4, 4, ShovePiece.hook(white));
    place(game, 6, 0, ShovePiece.shover(white));
    place(game, 1, 0, ShovePiece.shover(black));

    expect(
      game.getLegalMovesFrom(game.getSquareByXY(4, 4)!).map(describe).toSet(),
      {
        describe(moveOf(game, (4, 4), (3, 4))),
        describe(moveOf(game, (4, 4), (5, 4))),
        describe(moveOf(game, (4, 4), (4, 3))),
        describe(moveOf(game, (4, 4), (4, 5))),
      },
    );
  });

  test('a shover hops forward over a friendly leaper and undo restores it', () {
    final game = emptyGame();
    final shover = place(game, 5, 3, ShovePiece.shover(white));
    final leaper = place(game, 4, 3, ShovePiece.leaper(white));
    place(game, 1, 6, ShovePiece.shover(black));

    final hop = moveOf(game, (5, 3), (3, 3));
    expect(game.validateMove(hop), isTrue);
    expect(
      game.getLegalMovesFrom(game.getSquareByXY(5, 3)!).map(describe),
      contains(describe(hop)),
    );

    game.move(hop);
    expect(game.getSquareByXY(3, 3)!.pieceId, shover.id);
    expect(game.getSquareByXY(4, 3)!.pieceId, leaper.id);
    expect(game.pieces.values.any((p) => p.isIncapacitated), isFalse);

    game.undoLastMove();
    expect(game.getSquareByXY(5, 3)!.pieceId, shover.id);
    expect(game.getSquareByXY(3, 3)!.pieceId, isNull);
  });

  test(
    'a shover can only hop forward over its own leaper onto an empty square',
    () {
      final game = emptyGame();
      place(game, 5, 3, ShovePiece.shover(white));
      place(game, 4, 3, ShovePiece.blocker(white));
      place(game, 5, 5, ShovePiece.shover(white));
      place(game, 5, 4, ShovePiece.leaper(black));
      place(game, 5, 6, ShovePiece.shover(white));
      place(game, 4, 6, ShovePiece.leaper(white));
      place(game, 3, 6, ShovePiece.thrower(black));
      place(game, 6, 0, ShovePiece.shover(white));
      place(game, 5, 0, ShovePiece.leaper(white));
      place(game, 3, 1, ShovePiece.shover(white));
      place(game, 4, 1, ShovePiece.leaper(white));
      place(game, 1, 1, ShovePiece.shover(black));

      expect(game.validateMove(moveOf(game, (5, 3), (3, 3))), isFalse);
      expect(game.validateMove(moveOf(game, (5, 5), (5, 3))), isFalse);
      expect(game.validateMove(moveOf(game, (5, 6), (3, 6))), isFalse);
      expect(
        game.validateMove(moveOf(game, (3, 1), (5, 1))),
        isFalse,
        reason: 'backwards',
      );
      expect(game.validateMove(moveOf(game, (6, 0), (4, 0))), isTrue);
    },
  );

  test('hopping onto the goal row wins', () {
    final game = emptyGame();
    place(game, 2, 3, ShovePiece.shover(white));
    place(game, 1, 3, ShovePiece.leaper(white));
    place(game, 5, 6, ShovePiece.shover(black));

    game.move(moveOf(game, (2, 3), (0, 3)));

    expect(game.gameOverState?.winner, white);
    expect(game.gameOverReason, GameOverReason.reachedGoal);
  });

  test('every piece type has a positive value', () {
    for (final type in PieceType.values) {
      expect(type.pieceValue, greaterThan(0));
    }
  });
}
