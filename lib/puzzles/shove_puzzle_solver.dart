import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';

/// Exhaustive forced-win search, used to check the moves made in a puzzle.
///
/// "Within N moves" counts only the moves of the attacker, the side that wants to win.
class ShovePuzzleSolver {
  const ShovePuzzleSolver._();

  /// Whether the player to move on [game] can force a win within [moves] moves.
  static bool winsWithin(ShoveGame game, int moves) {
    final copy = game.copy();
    return _attackerWins(copy, copy.currentPlayersTurn, moves);
  }

  /// Whether the player who just moved on [game] still forces a win with [movesLeft] more moves.
  static bool stillWinsAfterMove(ShoveGame game, int movesLeft) {
    final copy = game.copy();
    return _afterAttack(
      copy,
      copy.getOpponent(copy.currentPlayersTurn),
      movesLeft,
    );
  }

  /// A move for the player to move on [game] that forces a win within [moves] moves.
  static ShoveGameMove? winningMove(ShoveGame game, int moves) {
    final copy = game.copy();
    final attacker = copy.currentPlayersTurn;
    for (final move in copy.getAllLegalMoves()) {
      copy.move(move);
      final wins = _afterAttack(copy, attacker, moves - 1);
      copy.undoLastMove();
      if (wins) return _onGame(move, game);
    }
    return null;
  }

  /// Every move for the player to move on [game] that forces a win within [moves] moves.
  static List<ShoveGameMove> winningMoves(ShoveGame game, int moves) {
    final copy = game.copy();
    final attacker = copy.currentPlayersTurn;
    final winning = <ShoveGameMove>[];
    for (final move in copy.getAllLegalMoves()) {
      copy.move(move);
      final wins = _afterAttack(copy, attacker, moves - 1);
      copy.undoLastMove();
      if (wins) winning.add(_onGame(move, game));
    }
    return winning;
  }

  /// The toughest reply for the defender, who is to move on [game], against an attacker
  /// that has [movesLeft] moves to win. Null if the defender has no legal move.
  static ShoveGameMove? bestDefense(ShoveGame game, int movesLeft) {
    final copy = game.copy();
    final attacker = copy.getOpponent(copy.currentPlayersTurn);

    var candidates = copy.getAllLegalMoves();
    if (candidates.isEmpty) return null;

    // Keep the replies that survive the longest
    for (var depth = 1; depth < movesLeft && candidates.length > 1; depth++) {
      final survivors = <ShoveGameMove>[];
      for (final reply in candidates) {
        copy.move(reply);
        final loses = _attackerWinsAfterReply(copy, attacker, depth);
        copy.undoLastMove();
        if (!loses) survivors.add(reply);
      }
      if (survivors.isEmpty) break;
      candidates = survivors;
    }
    return _onGame(candidates.first, game);
  }

  /// [attacker] is to move on [game] and wins within [movesLeft] moves.
  static bool _attackerWins(ShoveGame game, IPlayer attacker, int movesLeft) {
    if (movesLeft <= 0) return false;
    for (final move in game.getAllLegalMoves()) {
      game.move(move);
      final wins = _afterAttack(game, attacker, movesLeft - 1);
      game.undoLastMove();
      if (wins) return true;
    }
    return false;
  }

  /// [attacker] just moved on [game] and wins whatever the defender does, in [movesLeft] more moves.
  static bool _afterAttack(ShoveGame game, IPlayer attacker, int movesLeft) {
    if (game.isGameOver) return game.gameOverState?.winner == attacker;
    if (movesLeft <= 0) return false;

    for (final reply in game.getAllLegalMoves()) {
      game.move(reply);
      final wins = _attackerWinsAfterReply(game, attacker, movesLeft);
      game.undoLastMove();
      if (!wins) return false;
    }
    return true;
  }

  static bool _attackerWinsAfterReply(
    ShoveGame game,
    IPlayer attacker,
    int movesLeft,
  ) => game.isGameOver
      ? game.gameOverState?.winner == attacker
      : _attackerWins(game, attacker, movesLeft);

  static ShoveGameMove _onGame(ShoveGameMove move, ShoveGame game) {
    final thrower = move.throwerSquare;
    return ShoveGameMove(
      game.getSquareByXY(move.oldSquare.x, move.oldSquare.y)!,
      game.getSquareByXY(move.newSquare.x, move.newSquare.y)!,
      game.currentPlayersTurn,
      throwerSquare: thrower == null
          ? null
          : game.getSquareByXY(thrower.x, thrower.y),
    );
  }
}
