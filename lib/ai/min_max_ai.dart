import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_game_move_dto.dart';
import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator_service.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_square.dart';

class MinMaxAi extends IPlayer implements IAi {
  /// How long to think per move; longer means a deeper search and a stronger AI.
  final Duration thinkTime;

  /// Think on a background worker so the UI stays responsive.
  final bool useWorker;

  MinMaxAi(
    super.playerName,
    super.isWhite, {
    this.thinkTime = const Duration(seconds: 3),
    this.useWorker = true,
  });

  @override
  Future<ShoveGameMove> makeMove(ShoveGame game) async {
    if (!useWorker) {
      final result = _ShoveSearch(game).findBestMove(timeLimit: thinkTime);
      if (result == null) throw StateError('$playerName has no legal moves');
      return result.move;
    }

    final worker = ShoveGameEvaluatorServiceWorker();
    final String? bestMove;
    try {
      bestMove = await worker.findBestMove(
        jsonEncode(ShoveGameStateDto.fromGame(game).toJson()),
      );
    } finally {
      worker.stop();
    }

    final dto = ShoveGameMoveDto.fromJson(jsonDecode(bestMove!));
    final thrower = dto.throwerSquare;
    return ShoveGameMove(
      game.getSquareByXY(dto.oldSquare.x, dto.oldSquare.y)!,
      game.getSquareByXY(dto.newSquare.x, dto.newSquare.y)!,
      game.currentPlayersTurn,
      throwerSquare: thrower == null
          ? null
          : game.getSquareByXY(thrower.x, thrower.y),
    );
  }
}

class _SearchResult {
  final ShoveGameMove move;

  /// From the point of view of the player to move; 100 is roughly one shover.
  final int score;
  final int depth;

  const _SearchResult(this.move, this.score, this.depth);

  bool get isWinFound => score > _ShoveSearch.winThreshold;
  bool get isLossFound => score < -_ShoveSearch.winThreshold;
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
class _ShoveSearch {
  static const win = 1000000;
  static const winThreshold = win - 1000;
  static const _infinity = win + 1;
  static const _maxCachedPositions = 1000000;
  static const _maxQuiescenceDepth = 6;
  static const _squareCount =
      ShoveGame.totalNumberOfRows * ShoveGame.totalNumberOfColumns;
  static const _moveKeyCount = _squareCount * _squareCount * (_squareCount + 1);
  static const _noKillers = <int?>[null, null];

  final ShoveGame _source;
  final ShoveGame _game;

  final _cache = HashMap<int, _CachedResult>();
  final _history = List<int>.filled(_moveKeyCount, 0);
  final _killers = <List<int?>>[];
  final _positionPath = <int>[];

  /// The piece on every square, filled in by [evaluate] for cheap neighbour lookups.
  final _grid = List<ShovePiece?>.filled(_squareCount, null);

  late Stopwatch _clock;
  late Duration _timeLimit;
  var _nodes = 0;
  var _aborted = false;

  _ShoveSearch(ShoveGame game) : _source = game, _game = game.copy();

  /// Best move found within [timeLimit], or null if there are no legal moves.
  /// The returned move refers to the squares of the game passed in.
  _SearchResult? findBestMove({
    Duration timeLimit = const Duration(seconds: 3),
    int maxDepth = 64,
  }) {
    _clock = Stopwatch()..start();
    _timeLimit = timeLimit;
    _aborted = false;
    _nodes = 0;
    _history.fillRange(0, _history.length, 0);
    _killers.clear();

    final rootMoves = _game.getAllLegalMoves();
    if (rootMoves.isEmpty) return null;

    var best = _SearchResult(rootMoves.first, evaluate(), 0);

    for (var depth = 1; depth <= maxDepth; depth++) {
      final iteration = _searchRoot(rootMoves, depth, best.move);
      if (iteration != null) best = iteration;
      if (_aborted || best.isWinFound || best.isLossFound) break;
      // Each iteration takes a few times longer than the previous one
      if (_clock.elapsed * 3 > _timeLimit) break;
    }
    return _SearchResult(_onSourceGame(best.move), best.score, best.depth);
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

  _SearchResult? _searchRoot(
    List<ShoveGameMove> moves,
    int depth,
    ShoveGameMove previousBest,
  ) {
    final scores = _scoreMoves(moves, 0, _moveKey(previousBest));
    _positionPath
      ..clear()
      ..add(_game.positionKey);

    var alpha = -_infinity;
    ShoveGameMove? bestMove;
    var bestScore = -_infinity;

    for (var index = 0; index < moves.length; index++) {
      final move = _takeBest(moves, scores, index);
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
    return bestMove == null ? null : _SearchResult(bestMove, bestScore, depth);
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
    final scores = _scoreMoves(moves, ply, cached?.bestMoveKey);

    final originalAlpha = alpha;
    var bestScore = -_infinity;
    ShoveGameMove? bestMove;

    for (var index = 0; index < moves.length; index++) {
      final move = _takeBest(moves, scores, index);
      // Late quiet moves are probably bad: try them shallower first
      final reduction = depth >= 3 && index >= 4 && _isQuiet(move) ? 1 : 0;
      _game.move(move);

      int score;
      if (index == 0) {
        score = -_negamax(depth - 1, -beta, -alpha, ply + 1);
      } else {
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
        if (_isQuiet(move)) _rememberGoodQuietMove(move, ply, depth);
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

    final mustDefend = _opponentThreatensGoal();
    // Only shovers and chargers can score or eliminate; other moves matter when defending
    final moves = mustDefend
        ? _game.getAllLegalMoves()
        : _game.getLegalAttackerMoves();
    if (moves.any(_reachesGoal)) return win - ply - 1;

    final atLimit = quiescenceDepth >= _maxQuiescenceDepth;
    if (!mustDefend || atLimit) {
      final standPat = evaluate();
      if (atLimit || standPat >= beta) return standPat;
      alpha = max(alpha, standPat);
    }

    final candidates = mustDefend ? moves : moves.where(_eliminates).toList();
    final scores = _scoreMoves(candidates, ply, null);

    var bestScore = mustDefend ? -_infinity : alpha;
    for (var index = 0; index < candidates.length; index++) {
      final move = _takeBest(candidates, scores, index);
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
    return (index(move.oldSquare) * _squareCount + index(move.newSquare)) *
            (_squareCount + 1) +
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
    _history[key] += depth * depth;
  }

  /// Ordering score per move (higher is searched first).
  List<int> _scoreMoves(List<ShoveGameMove> moves, int ply, int? bestMoveKey) {
    final killers = ply < _killers.length ? _killers[ply] : _noKillers;
    return [for (final move in moves) _orderScore(move, bestMoveKey, killers)];
  }

  /// Moves the best scored move from [index] onwards to [index] and returns it.
  /// Picking lazily is cheaper than sorting, as most nodes cut off early.
  ShoveGameMove _takeBest(
    List<ShoveGameMove> moves,
    List<int> scores,
    int index,
  ) {
    var best = index;
    for (var i = index + 1; i < moves.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }

    final move = moves[best];
    if (best != index) {
      final score = scores[best];
      // Shift instead of swap so equally scored moves keep their order
      moves.setRange(index + 1, best + 1, moves, index);
      scores.setRange(index + 1, best + 1, scores, index);
      moves[index] = move;
      scores[index] = score;
    }
    return move;
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

    var score = _history[key];
    if (_piece(move.oldSquare)?.pieceType == PieceType.shover &&
        move.newSquare.y == move.oldSquare.y) {
      score += 50;
    }
    return score;
  }

  ShovePiece? _piece(ShoveSquare square) => _game.pieceOn(square);

  /// The opponent piece a move shoves, throws or leaps over (and so stuns).
  ShovePiece? _victim(ShoveGameMove move) {
    if (move.shoveGameMoveType == ShoveGameMoveType.thrown) {
      final thrown = _piece(move.oldSquare);
      return thrown?.owner == _game.currentPlayersTurn ? null : thrown;
    }
    final mover = _piece(move.oldSquare);
    if (mover?.pieceType == PieceType.shover ||
        mover?.pieceType == PieceType.charger) {
      return _piece(move.newSquare);
    }
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
      _game.getSquaresDistanceToGoal(
            _game.currentPlayersTurn,
            move.newSquare,
          ) ==
          0 &&
      move.shoveGameMoveType == ShoveGameMoveType.move &&
      _piece(move.oldSquare)?.pieceType == PieceType.shover;

  bool _eliminates(ShoveGameMove move) {
    if (move.shoveGameMoveType == ShoveGameMoveType.thrown ||
        move.newSquare.pieceId == null) {
      return false;
    }
    final type = _piece(move.oldSquare)?.pieceType;
    if (type == PieceType.shover) {
      return _game.isOutOfBounds(
        2 * move.newSquare.x - move.oldSquare.x,
        2 * move.newSquare.y - move.oldSquare.y,
      );
    }
    if (type != PieceType.charger) return false;
    final (x, y) = _game.chargeShoveTarget(move.oldSquare, move.newSquare);
    return _game.isOutOfBounds(x, y);
  }

  /// Whether a shover of the opponent is one step from its goal and not held back.
  bool _opponentThreatensGoal() {
    final opponent = _game.getOpponent(_game.currentPlayersTurn);
    final forward = _game.forwardDirectionOf(opponent);
    final lastRow = _game.goalRowOf(opponent) - forward;

    for (var y = 0; y < ShoveGame.totalNumberOfColumns; y++) {
      final shover = _game.pieceOn(_game.getSquareByXY(lastRow, y)!);
      if (shover == null ||
          shover.pieceType != PieceType.shover ||
          shover.owner != opponent) {
        continue;
      }
      final target = _game.pieceOn(_game.getSquareByXY(lastRow + forward, y)!);
      if (target == null ||
          (target.owner != opponent && target.pieceType != PieceType.blocker)) {
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
    PieceType.charger => 320,
    PieceType.hook => 280,
  };

  /// Bonus by rows left to the goal.
  static const _shoverAdvance = [0, 260, 120, 60, 30, 12, 0, 0];
  static const _passedShoverBonus = [0, 220, 120, 60, 30, 15, 5, 0];

  /// Static evaluation from the point of view of the player to move.
  int evaluate() {
    final me = _game.currentPlayersTurn;
    final squares = _game.squares;
    for (var i = 0; i < squares.length; i++) {
      _grid[i] = _piece(squares[i]);
    }

    var myShovers = 0;
    var theirShovers = 0;
    var score = 0;

    for (var i = 0; i < squares.length; i++) {
      final piece = _grid[i];
      if (piece == null) continue;
      final square = squares[i];
      final owner = piece.owner;
      final isMine = owner == me;
      var value = _value(piece.pieceType);

      if (piece.pieceType == PieceType.shover) {
        if (isMine) {
          myShovers++;
        } else {
          theirShovers++;
        }
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
        final neighbor = _grid[_gridIndex(neighborSquare.x, neighborSquare.y)];
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
        value -= _value(piece.pieceType) ~/ (isMine ? 4 : 2);
      }

      score += isMine ? value : -value;
    }

    score += _shoverScarcity(myShovers) - _shoverScarcity(theirShovers);
    const tempo = 10;
    return score + tempo;
  }

  static int _shoverScarcity(int shovers) => switch (shovers) {
    1 => -250,
    2 => -90,
    3 => -30,
    _ => 0,
  };

  static int _gridIndex(int x, int y) => x * ShoveGame.totalNumberOfColumns + y;

  /// The piece on (x, y) as seen by [evaluate]; null outside the board.
  ShovePiece? _gridPiece(int x, int y) =>
      _game.isOutOfBounds(x, y) ? null : _grid[_gridIndex(x, y)];

  /// No enemy piece ahead of the shover in its own or neighboring columns.
  bool _isUnopposed(ShoveSquare square, IPlayer owner) {
    final step = _game.forwardDirectionOf(owner);
    for (var x = square.x + step; !_game.isOutOfBounds(x, 0); x += step) {
      for (var y = square.y - 1; y <= square.y + 1; y++) {
        final piece = _gridPiece(x, y);
        if (piece != null && piece.owner != owner) return false;
      }
    }
    return true;
  }

  bool _canBeShovedOffBoard(ShoveSquare square, IPlayer owner) {
    final enemy = _game.getOpponent(owner);
    return _isPushedOffBoard(
          square,
          enemy,
          _game.forwardDirectionOf(enemy),
          0,
        ) ||
        _isPushedOffBoard(square, enemy, 0, -1) ||
        _isPushedOffBoard(square, enemy, 0, 1);
  }

  /// An active shover of [enemy] stands opposite the edge that (dx, dy) points to.
  bool _isPushedOffBoard(ShoveSquare square, IPlayer enemy, int dx, int dy) {
    if (!_game.isOutOfBounds(square.x + dx, square.y + dy)) return false;
    final shover = _gridPiece(square.x - dx, square.y - dy);
    return shover != null &&
        shover.pieceType == PieceType.shover &&
        shover.owner == enemy &&
        !shover.isIncapacitated;
  }
}
