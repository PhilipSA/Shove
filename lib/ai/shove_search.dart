import 'dart:collection';
import 'dart:math';

import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_square.dart';

class SearchResult {
  final ShoveGameMove move;

  /// From the point of view of the player to move; 100 is roughly one shover.
  final int score;
  final int depth;

  const SearchResult(this.move, this.score, this.depth);

  bool get isWinFound => score > ShoveSearch.winThreshold;
  bool get isLossFound => score < -ShoveSearch.winThreshold;
}

enum _Bound { exact, lower, upper }

class _CachedResult {
  final int depth;
  final int score;
  final _Bound bound;
  final int? bestMoveKey;

  const _CachedResult(this.depth, this.score, this.bound, this.bestMoveKey);
}

/// Iterative deepening alpha-beta search used by the AI players.
///
/// It thinks on a private copy of the game, using the game's own move/undo, so
/// the rules exist in one place only and the real game is never touched.
class ShoveSearch {
  static const win = 1000000;
  static const winThreshold = win - 1000;
  static const _infinity = win + 1;
  static const _maxCachedPositions = 1000000;
  static const _maxQuiescenceDepth = 6;

  final ShoveGame _source;
  final ShoveGame _game;

  final _cache = HashMap<int, _CachedResult>();
  final _history = HashMap<int, int>();
  final _killers = <List<int?>>[];
  final _positionPath = <int>[];

  late Stopwatch _clock;
  late Duration _timeLimit;
  var _nodes = 0;
  var _aborted = false;

  ShoveSearch(ShoveGame game) : _source = game, _game = game.copy();

  /// Best move found within [timeLimit], or null if there are no legal moves.
  /// The returned move refers to the squares of the game passed in.
  SearchResult? findBestMove({
    Duration timeLimit = const Duration(seconds: 3),
    int maxDepth = 64,
  }) {
    _clock = Stopwatch()..start();
    _timeLimit = timeLimit;
    _aborted = false;
    _nodes = 0;
    _history.clear();
    _killers.clear();

    final rootMoves = _game.getAllLegalMoves();
    if (rootMoves.isEmpty) return null;

    var best = SearchResult(rootMoves.first, evaluate(), 0);

    for (var depth = 1; depth <= maxDepth; depth++) {
      final iteration = _searchRoot(rootMoves, depth, best.move);
      if (iteration != null) best = iteration;
      if (_aborted || best.isWinFound || best.isLossFound) break;
      // Each iteration takes a few times longer than the previous one
      if (_clock.elapsed * 3 > _timeLimit) break;
    }
    return SearchResult(_onSourceGame(best.move), best.score, best.depth);
  }

  ShoveGameMove _onSourceGame(ShoveGameMove move) {
    ShoveSquare square(ShoveSquare s) => _source.getSquareByXY(s.x, s.y)!;
    final thrower = move.throwerSquare;
    return ShoveGameMove(
      square(move.oldSquare),
      square(move.newSquare),
      _source.currentPlayersTurn,
      throwerSquare: thrower == null ? null : square(thrower),
    );
  }

  SearchResult? _searchRoot(
    List<ShoveGameMove> moves,
    int depth,
    ShoveGameMove previousBest,
  ) {
    _orderMoves(moves, 0, _moveKey(previousBest));
    _positionPath
      ..clear()
      ..add(_game.positionKey);

    var alpha = -_infinity;
    ShoveGameMove? bestMove;
    var bestScore = -_infinity;

    for (final (index, move) in moves.indexed) {
      _game.move(move);
      // Later moves only need to prove they beat the best so far
      var score = index == 0
          ? -_negamax(depth - 1, -_infinity, -alpha, 1)
          : -_negamax(depth - 1, -alpha - 1, -alpha, 1);
      if (index > 0 && !_aborted && score > alpha) {
        score = -_negamax(depth - 1, -_infinity, -alpha, 1);
      }
      _game.undoLastMove();

      if (_aborted) break;
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
      alpha = max(alpha, score);
    }

    // Moves are tried previous-best first, so a cut-short iteration is still usable
    return bestMove == null ? null : SearchResult(bestMove, bestScore, depth);
  }

  int _negamax(int depth, int alpha, int beta, int ply) {
    if (_outOfTime()) return 0;
    if (_game.isGameOver) return _gameOverScore(ply);

    final key = _game.positionKey;
    _positionPath
      ..length = ply
      ..add(key);
    if (_isRepetition(ply, key)) return 0;

    if (depth <= 0) return _quiesce(alpha, beta, ply, 0);

    final cached = _cache[key];
    if (cached != null && cached.depth >= depth) {
      final score = _scoreFromCache(cached.score, ply);
      final usable = switch (cached.bound) {
        _Bound.exact => true,
        _Bound.lower => score >= beta,
        _Bound.upper => score <= alpha,
      };
      if (usable) return score;
    }

    final moves = _game.getAllLegalMoves();
    _orderMoves(moves, ply, cached?.bestMoveKey);

    final originalAlpha = alpha;
    var bestScore = -_infinity;
    ShoveGameMove? bestMove;

    for (final (index, move) in moves.indexed) {
      final quiet = _isQuiet(move);
      _game.move(move);

      int score;
      if (index == 0) {
        score = -_negamax(depth - 1, -beta, -alpha, ply + 1);
      } else {
        // Late quiet moves are probably bad: try them shallower first
        final reduction = depth >= 3 && index >= 4 && quiet ? 1 : 0;
        score = -_negamax(depth - 1 - reduction, -alpha - 1, -alpha, ply + 1);
        if (!_aborted && score > alpha && reduction > 0) {
          score = -_negamax(depth - 1, -alpha - 1, -alpha, ply + 1);
        }
        if (!_aborted && score > alpha && score < beta) {
          score = -_negamax(depth - 1, -beta, -alpha, ply + 1);
        }
      }
      _game.undoLastMove();

      if (_aborted) return 0;

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
      alpha = max(alpha, score);
      if (alpha >= beta) {
        if (quiet) _rememberGoodQuietMove(move, ply, depth);
        break;
      }
    }

    if (_cache.length > _maxCachedPositions) _cache.clear();
    _cache[key] = _CachedResult(
      depth,
      _scoreToCache(bestScore, ply),
      bestScore <= originalAlpha
          ? _Bound.upper
          : bestScore >= beta
          ? _Bound.lower
          : _Bound.exact,
      bestMove == null ? null : _moveKey(bestMove),
    );
    return bestScore;
  }

  /// Plays out forcing moves (eliminations, stopping a shover about to score)
  /// so the evaluation is not taken in the middle of a fight.
  int _quiesce(int alpha, int beta, int ply, int quiescenceDepth) {
    if (_outOfTime()) return 0;
    if (_game.isGameOver) return _gameOverScore(ply);

    final moves = _game.getAllLegalMoves();
    if (moves.any(_reachesGoal)) return win - ply - 1;

    final mustDefend = _opponentThreatensGoal();
    final atLimit = quiescenceDepth >= _maxQuiescenceDepth;
    if (!mustDefend || atLimit) {
      final standPat = evaluate();
      if (atLimit || standPat >= beta) return standPat;
      alpha = max(alpha, standPat);
    }

    final candidates = mustDefend ? moves : moves.where(_eliminates).toList();
    _orderMoves(candidates, ply, null);

    var bestScore = mustDefend ? -_infinity : alpha;
    for (final move in candidates) {
      _game.move(move);
      final score = -_quiesce(-beta, -alpha, ply + 1, quiescenceDepth + 1);
      _game.undoLastMove();
      if (_aborted) return 0;

      bestScore = max(bestScore, score);
      alpha = max(alpha, score);
      if (alpha >= beta) break;
    }
    return bestScore;
  }

  bool _outOfTime() {
    if (++_nodes % 256 == 0 && _clock.elapsed >= _timeLimit) _aborted = true;
    return _aborted;
  }

  int _gameOverScore(int ply) {
    final winner = _game.gameOverState?.winner;
    if (winner == null) return 0;
    return winner == _game.currentPlayersTurn ? win - ply : -(win - ply);
  }

  bool _isRepetition(int ply, int key) {
    for (var p = ply - 2; p >= 0; p -= 2) {
      if (_positionPath[p] == key) return true;
    }
    return false;
  }

  // Win scores are stored relative to the cached position, not the root.
  static int _scoreToCache(int score, int ply) => score > winThreshold
      ? score + ply
      : score < -winThreshold
      ? score - ply
      : score;

  static int _scoreFromCache(int score, int ply) => score > winThreshold
      ? score - ply
      : score < -winThreshold
      ? score + ply
      : score;

  // ------------------------------------------------------------ move order

  int _moveKey(ShoveGameMove move) {
    int index(ShoveSquare s) => s.x * ShoveGame.totalNumberOfColumns + s.y;
    final thrower = move.throwerSquare;
    return (index(move.oldSquare) * 64 + index(move.newSquare)) * 65 +
        (thrower == null ? 0 : index(thrower) + 1);
  }

  void _rememberGoodQuietMove(ShoveGameMove move, int ply, int depth) {
    while (_killers.length <= ply) {
      _killers.add([null, null]);
    }
    final key = _moveKey(move);
    final killers = _killers[ply];
    if (killers[0] != key) {
      killers[1] = killers[0];
      killers[0] = key;
    }
    _history.update(
      key,
      (v) => v + depth * depth,
      ifAbsent: () => depth * depth,
    );
  }

  void _orderMoves(List<ShoveGameMove> moves, int ply, int? bestMoveKey) {
    final killers = ply < _killers.length ? _killers[ply] : const [null, null];
    final scored = [
      for (final move in moves) (move, _orderScore(move, bestMoveKey, killers)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    moves.setAll(0, scored.map((entry) => entry.$1));
  }

  int _orderScore(ShoveGameMove move, int? bestMoveKey, List<int?> killers) {
    final key = _moveKey(move);
    if (key == bestMoveKey) return 1 << 30;
    if (_reachesGoal(move)) return 1 << 29;

    final victim = _victim(move);
    if (_eliminates(move)) return (1 << 28) + _value(victim!.pieceType);
    if (victim != null) return (1 << 26) + _value(victim.pieceType);

    if (key == killers[0]) return 1 << 24;
    if (key == killers[1]) return (1 << 24) - 1;

    var score = _history[key] ?? 0;
    if (_piece(move.oldSquare)?.pieceType == PieceType.shover &&
        move.newSquare.y == move.oldSquare.y) {
      score += 50;
    }
    return score;
  }

  ShovePiece? _piece(ShoveSquare square) => _game.pieces[square.pieceId];

  /// The opponent piece a move shoves, throws or leaps over (and so stuns).
  ShovePiece? _victim(ShoveGameMove move) {
    if (move.shoveGameMoveType == ShoveGameMoveType.thrown) {
      return _piece(move.oldSquare);
    }
    final mover = _piece(move.oldSquare);
    if (mover?.pieceType == PieceType.shover) return _piece(move.newSquare);
    if (mover?.pieceType == PieceType.leaper) {
      final dx = move.newSquare.x - move.oldSquare.x;
      final dy = move.newSquare.y - move.oldSquare.y;
      if (dx.abs() < 2 && dy.abs() < 2) return null;
      final jumped = _game.getSquareByXY(
        move.oldSquare.x + dx ~/ 2,
        move.oldSquare.y + dy ~/ 2,
      );
      final piece = jumped == null ? null : _piece(jumped);
      return piece?.owner == mover!.owner ? null : piece;
    }
    return null;
  }

  bool _isQuiet(ShoveGameMove move) =>
      _victim(move) == null && !_reachesGoal(move);

  bool _reachesGoal(ShoveGameMove move) =>
      move.shoveGameMoveType == ShoveGameMoveType.move &&
      _piece(move.oldSquare)?.pieceType == PieceType.shover &&
      _game.getSquaresDistanceToGoal(
            _game.currentPlayersTurn,
            move.newSquare,
          ) ==
          0;

  bool _eliminates(ShoveGameMove move) {
    if (move.shoveGameMoveType == ShoveGameMoveType.thrown ||
        move.newSquare.pieceId == null ||
        _piece(move.oldSquare)?.pieceType != PieceType.shover) {
      return false;
    }
    return _game.isOutOfBounds(
      2 * move.newSquare.x - move.oldSquare.x,
      2 * move.newSquare.y - move.oldSquare.y,
    );
  }

  bool _opponentThreatensGoal() {
    for (final square in _game.squares) {
      final shover = _piece(square);
      if (shover == null ||
          shover.pieceType != PieceType.shover ||
          shover.owner == _game.currentPlayersTurn ||
          _game.getSquaresDistanceToGoal(shover.owner, square) != 1) {
        continue;
      }
      final goal = _game.getSquareByXY(
        square.x + _game.forwardDirectionOf(shover.owner),
        square.y,
      )!;
      final target = _piece(goal);
      if (target == null ||
          (target.owner != shover.owner &&
              target.pieceType != PieceType.blocker)) {
        return true;
      }
    }
    return false;
  }

  // ------------------------------------------------------------ evaluation

  static int _value(PieceType type) => switch (type) {
    PieceType.shover => 160,
    PieceType.thrower => 300,
    PieceType.blocker => 200,
    PieceType.leaper => 260,
  };

  /// Bonus by rows left to the goal.
  static const _shoverAdvance = [0, 260, 120, 60, 30, 12, 0, 0];
  static const _passedShoverBonus = [0, 220, 120, 60, 30, 15, 5, 0];

  /// Static evaluation from the point of view of the player to move.
  int evaluate() {
    final me = _game.currentPlayersTurn;
    final shoversLeft = {for (final player in _game.players) player: 0};
    var score = 0;

    for (final square in _game.squares) {
      final piece = _piece(square);
      if (piece == null) continue;
      final owner = piece.owner;
      var value = _value(piece.pieceType);

      if (piece.pieceType == PieceType.shover) {
        shoversLeft[owner] = shoversLeft[owner]! + 1;
        final rowsLeft = _game.getSquaresDistanceToGoal(owner, square);
        value += _shoverAdvance[rowsLeft];
        if (_isUnopposed(square, owner)) {
          value += _passedShoverBonus[rowsLeft];
        }
      }

      if (piece.isIncapacitated) value -= 30;

      var attackable = 0;
      var guardedByBlocker = false;
      for (final neighborSquare in _game.getAllNeighborSquares(square)) {
        final neighbor = _piece(neighborSquare);
        if (neighbor == null) continue;
        if (neighbor.owner != owner) {
          if (neighbor.pieceType != PieceType.blocker) attackable++;
        } else if (neighbor.pieceType == PieceType.blocker) {
          guardedByBlocker = true;
        }
      }
      value += switch (piece.pieceType) {
        PieceType.thrower => attackable * 14,
        PieceType.leaper => attackable * 6,
        _ => 0,
      };
      if (guardedByBlocker && piece.pieceType != PieceType.blocker) value += 10;

      if (piece.pieceType != PieceType.blocker &&
          _canBeShovedOffBoard(square, owner)) {
        // Much worse if the opponent gets to do it right now
        value -= _value(piece.pieceType) ~/ (owner == me ? 4 : 2);
      }

      score += owner == me ? value : -value;
    }

    for (final MapEntry(key: player, value: shovers) in shoversLeft.entries) {
      final scarcity = _shoverScarcity(shovers);
      score += player == me ? scarcity : -scarcity;
    }
    const tempo = 10;
    return score + tempo;
  }

  static int _shoverScarcity(int shovers) => switch (shovers) {
    1 => -250,
    2 => -90,
    3 => -30,
    _ => 0,
  };

  /// No enemy piece ahead of the shover in its own or neighboring columns.
  bool _isUnopposed(ShoveSquare square, IPlayer owner) {
    final step = _game.forwardDirectionOf(owner);
    for (var x = square.x + step; !_game.isOutOfBounds(x, 0); x += step) {
      for (var y = square.y - 1; y <= square.y + 1; y++) {
        final ahead = _game.getSquareByXY(x, y);
        final piece = ahead == null ? null : _piece(ahead);
        if (piece != null && piece.owner != owner) return false;
      }
    }
    return true;
  }

  bool _canBeShovedOffBoard(ShoveSquare square, IPlayer owner) {
    for (final enemy in _game.players) {
      if (enemy == owner) continue;
      final forward = _game.forwardDirectionOf(enemy);
      for (final (dx, dy) in [(forward, 0), (0, -1), (0, 1)]) {
        if (!_game.isOutOfBounds(square.x + dx, square.y + dy)) continue;
        final shoverSquare = _game.getSquareByXY(square.x - dx, square.y - dy);
        final shover = shoverSquare == null ? null : _piece(shoverSquare);
        if (shover != null &&
            shover.pieceType == PieceType.shover &&
            shover.owner == enemy &&
            !shover.isIncapacitated) {
          return true;
        }
      }
    }
    return false;
  }
}
