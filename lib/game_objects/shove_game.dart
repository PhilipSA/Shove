import 'dart:collection';

import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/ai/min_max_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
import 'package:shove/game_objects/dto/shove_player_dto.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_direction.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_square.dart';
import 'package:shove/resources/shove_assets.dart';

enum GameOverReason { reachedGoal, noShoversLeft, noLegalMoves, repetition }

class ShoveGame {
  final Map<String, ShovePiece> pieces;
  final List<ShoveGameMove> allMadeMoves = [];

  static const int totalNumberOfRows = 8;
  static const int totalNumberOfColumns = 8;

  static const _player1GoalRow = 0;
  static const _player2GoalRow = totalNumberOfRows - 1;

  final IPlayer player1;
  final IPlayer player2;

  IPlayer currentPlayersTurn;
  ({IPlayer? winner, bool isOver})? gameOverState;
  GameOverReason? gameOverReason;

  bool get isGameOver => gameOverState?.isOver == true;
  bool get isDraw =>
      gameOverState?.winner == null && gameOverState?.isOver == true;

  final HashMap<(int x, int y), ShoveSquare> board;

  /// Fast row-major view of [board]; squares never change after construction.
  late final List<ShoveSquare> squares = [
    for (var x = 0; x < totalNumberOfRows; x++)
      for (var y = 0; y < totalNumberOfColumns; y++) board[(x, y)]!,
  ];

  late final List<List<ShoveSquare>> _neighbors = [
    for (final square in squares)
      List.unmodifiable(_computeNeighborSquares(square)),
  ];

  List<ShovePiece> get incapacitatedPieces =>
      pieces.values.where((element) => element.isIncapacitated).toList();

  final List<ShoveSquare> player1GoalShoveSquares = [];
  final List<ShoveSquare> player2GoalShoveSquares = [];

  ShoveGame(
    this.player1,
    this.player2, {
    HashMap<(int x, int y), ShoveSquare>? customBoard,
    Map<String, ShovePiece>? customPieces,
    IPlayer? currentPlayersTurn,
  }) : currentPlayersTurn = currentPlayersTurn ?? player1,
       pieces = customPieces ?? getInitialPieces(player1, player2),
       board = customBoard ?? HashMap() {
    if (customBoard == null) {
      for (int i = 0; i < totalNumberOfRows; i++) {
        for (int j = 0; j < totalNumberOfColumns; j++) {
          ShoveSquare square = ShoveSquare(i, j, null);

          board[(i, j)] = square;
        }
      }

      List<String> shoverIdsOf(IPlayer owner) => [
        for (final piece in pieces.values)
          if (piece.owner == owner && piece.pieceType == PieceType.shover)
            piece.id,
      ];
      final player1Shovers = shoverIdsOf(player1);
      final player2Shovers = shoverIdsOf(player2);
      for (var col = 0; col < totalNumberOfColumns; col++) {
        getSquareByXY(1, col)?.pieceId = player2Shovers[col];
        getSquareByXY(6, col)?.pieceId = player1Shovers[col];
      }

      for (var col = 0; col < backRank.length; col++) {
        _addPieceToSquare(7, col, backRank[col](player1));
        _addPieceToSquare(0, col, backRank[col](player2));
      }
    }

    for (var col = 0; col < totalNumberOfColumns; col++) {
      player1GoalShoveSquares.add(getSquareByXY(_player1GoalRow, col)!);
      player2GoalShoveSquares.add(getSquareByXY(_player2GoalRow, col)!);
    }
  }

  factory ShoveGame.fromDto(ShoveGameStateDto dto) {
    final player1 = IPlayer.fromDto(dto.player1);
    final player2 = IPlayer.fromDto(dto.player2);
    // Reuse the same player instances everywhere so comparisons stay cheap
    IPlayer player(ShovePlayerDto playerDto) =>
        playerDto == player1 ? player1 : player2;

    final board = HashMap<(int x, int y), ShoveSquare>();
    for (final squareDto in dto.board.values) {
      final square = ShoveSquare.fromDto(squareDto);
      board[(square.x, square.y)] = square;
    }

    final pieces = {
      for (final MapEntry(:key, value: piece) in dto.pieces.entries)
        key: ShovePiece(piece.id, piece.pieceType, null, player(piece.owner))
          ..isIncapacitated = piece.isIncapacitated,
    };

    final gameOver = dto.gameOverState;

    return ShoveGame(
        player1,
        player2,
        customBoard: board,
        customPieces: pieces,
        currentPlayersTurn: player(dto.currentPlayersTurn),
      )
      ..allMadeMoves.addAll(dto.allMadeMoves.map(ShoveGameMove.fromDto))
      ..gameOverState = gameOver == null
          ? null
          : (winner: player(gameOver.winner!), isOver: gameOver.isOver);
  }

  /// Independent copy, e.g. for an AI to think on without touching this game.
  ShoveGame copy() =>
      _cloneWith([for (final move in allMadeMoves) move.detached()]);

  /// Frozen copy of the current position for viewing; it shares the made moves with this game.
  ShoveGame snapshot() => _cloneWith(allMadeMoves);

  ShoveGame _cloneWith(Iterable<ShoveGameMove> madeMoves) {
    final clonedBoard = HashMap<(int x, int y), ShoveSquare>();
    for (final square in squares) {
      clonedBoard[(square.x, square.y)] = square.copy();
    }

    return ShoveGame(
        player1,
        player2,
        customBoard: clonedBoard,
        customPieces: {
          for (final MapEntry(:key, value: piece) in pieces.entries)
            key: ShovePiece(
              piece.id,
              piece.pieceType,
              piece.texture,
              piece.owner,
            )..isIncapacitated = piece.isIncapacitated,
        },
        currentPlayersTurn: currentPlayersTurn,
      )
      ..allMadeMoves.addAll(madeMoves)
      ..gameOverState = gameOverState
      ..gameOverReason = gameOverReason;
  }

  /// Back rank, the same for both players.
  static const List<ShovePiece Function(IPlayer)> backRank = [
    ShovePiece.blocker,
    ShovePiece.leaper,
    ShovePiece.thrower,
    ShovePiece.charger,
    ShovePiece.hook,
    ShovePiece.thrower,
    ShovePiece.leaper,
    ShovePiece.blocker,
  ];

  static Map<String, ShovePiece> getInitialPieces(
    IPlayer player1,
    IPlayer player2,
  ) {
    final player1Shovers = Map<String, ShovePiece>.fromIterable(
      List.generate(
        totalNumberOfColumns,
        (index) => ShovePiece.shover(player1),
      ),
      key: (e) => e.id,
    );

    final player2Shovers = Map<String, ShovePiece>.fromIterable(
      List.generate(
        totalNumberOfColumns,
        (index) => ShovePiece.shover(player2),
      ),
      key: (e) => e.id,
    );

    return player1Shovers..addAll(player2Shovers);
  }

  bool validateThrow(
    ShoveSquare thrower,
    ShoveSquare thrownFromSquare,
    ShoveSquare thrownToSquare,
  ) {
    return _canThrow(thrower, thrownFromSquare) &&
        (thrower.x - thrownFromSquare.x).abs() <= 1 &&
        (thrower.y - thrownFromSquare.y).abs() <= 1 &&
        !isOutOfBounds(thrownToSquare.x, thrownToSquare.y) &&
        thrownToSquare.pieceId == null &&
        (thrower.x - thrownToSquare.x).abs() <= 1 &&
        (thrower.y - thrownToSquare.y).abs() <= 1;
  }

  /// How far away a hook can pull a piece from.
  static const _hookRange = 3;

  /// Whether the current player's hook on [hook] may pull the piece on [from] to [to].
  bool validatePull(ShoveSquare hook, ShoveSquare from, ShoveSquare to) {
    final landing = _pullLanding(hook, from);
    return landing != null && landing.x == to.x && landing.y == to.y;
  }

  /// Where the piece on [target] ends up when the current player's hook on [hook]
  /// pulls it, or null if it cannot be pulled.
  ShoveSquare? _pullLanding(ShoveSquare hook, ShoveSquare target) {
    final dx = target.x - hook.x;
    final dy = target.y - hook.y;
    final distance = dx.abs() + dy.abs();
    final pulled = pieceOn(target);
    if ((dx != 0 && dy != 0) ||
        distance < 2 ||
        distance > _hookRange ||
        pulled == null ||
        !_isReadyPiece(hook, PieceType.hook) ||
        !(_isCurrentPlayer(pulled.owner) || _isThrowableEnemy(target))) {
      return null;
    }

    // The line between the hook and its target has to be clear
    for (var step = 1; step < distance; step++) {
      if (getSquareByXY(
            hook.x + dx.sign * step,
            hook.y + dy.sign * step,
          )!.pieceId !=
          null) {
        return null;
      }
    }
    return getSquareByXY(hook.x + dx.sign, hook.y + dy.sign);
  }

  /// Whether the piece on [square] is a ready piece of [type] owned by the current player.
  bool _isReadyPiece(ShoveSquare square, PieceType type) {
    final piece = pieceOn(square);
    return piece != null &&
        piece.pieceType == type &&
        !piece.isIncapacitated &&
        _isCurrentPlayer(piece.owner);
  }

  /// Whether the current player's [thrower] may throw the piece on [thrown] somewhere.
  bool _canThrow(ShoveSquare thrower, ShoveSquare thrown) =>
      thrower != thrown &&
      _isReadyPiece(thrower, PieceType.thrower) &&
      _isThrowableEnemy(thrown);

  /// Whether the piece on [thrown] is an enemy that throws and hooks can move.
  bool _isThrowableEnemy(ShoveSquare thrown) {
    final thrownPiece = pieceOn(thrown);
    if (thrownPiece == null ||
        thrownPiece.pieceType == PieceType.blocker ||
        thrownPiece.isIncapacitated ||
        _isCurrentPlayer(thrownPiece.owner)) {
      return false;
    }

    // A piece beside its own blocker cannot be thrown
    for (final neighbor in getAllNeighborSquares(thrown)) {
      final piece = pieceOn(neighbor);
      if (piece != null &&
          piece.pieceType == PieceType.blocker &&
          !_isCurrentPlayer(piece.owner)) {
        return false;
      }
    }
    return true;
  }

  /// The piece standing on [square], if any.
  ShovePiece? pieceOn(ShoveSquare square) {
    final id = square.pieceId;
    return id == null ? null : pieces[id];
  }

  bool validateMove(ShoveGameMove shoveGameMove) {
    final from = shoveGameMove.oldSquare;
    final to = shoveGameMove.newSquare;

    if (isGameOver || (from.x == to.x && from.y == to.y)) {
      return false;
    }

    final piece = pieceOn(from);
    if (piece == null) {
      return false;
    }

    // Stunned pieces cannot move, but a friendly hook can still pull them
    final throwerSquare = shoveGameMove.throwerSquare;
    if (throwerSquare != null) {
      return pieceOn(throwerSquare)?.pieceType == PieceType.hook
          ? validatePull(throwerSquare, from, to)
          : validateThrow(throwerSquare, from, to);
    }

    return !piece.isIncapacitated && _isLegalStep(piece, from, to);
  }

  /// Rules for moving the current player's [piece] from [from] to [to] without a throw.
  bool _isLegalStep(ShovePiece piece, ShoveSquare from, ShoveSquare to) {
    if (!_isCurrentPlayer(piece.owner) || isOutOfBounds(to.x, to.y)) {
      return false;
    }

    final target = pieceOn(to);
    final isOccupied = to.pieceId != null;
    final dx = (from.x - to.x).abs();
    final dy = (from.y - to.y).abs();

    switch (piece.pieceType) {
      case PieceType.shover:
        // Hop forward over a friendly leaper onto an empty square
        if (dx == 2 && dy == 0) {
          final leaper = pieceOn(getSquareByXY((from.x + to.x) ~/ 2, from.y)!);
          return target == null &&
              to.x - from.x == 2 * forwardDirectionOf(piece.owner) &&
              leaper?.pieceType == PieceType.leaper &&
              leaper?.owner == piece.owner;
        }

        // One step forward or sideways, never diagonally
        if (dx + dy != 1) {
          return false;
        }

        if ((to.x - from.x) * forwardDirectionOf(piece.owner) < 0) {
          return false;
        }

        // Shovers cannot shove blockers
        if (target?.pieceType == PieceType.blocker) {
          return false;
        }

        // Shovers cannot shove if it results in a collision with another piece
        if (isOccupied &&
            shoveResultsInCollision(
              calculateShoveDirection(from, to)!,
              to.x,
              to.y,
            )) {
          return false;
        }

      case PieceType.blocker:
        if ((dx > 0 && dy > 0) || dx > 2 || dy > 2) {
          return false;
        }

        // A two square jump needs an empty square in between
        if ((dx > 1 || dy > 1) &&
            getSquareByXY(
                  (from.x + to.x) ~/ 2,
                  (from.y + to.y) ~/ 2,
                )!.pieceId !=
                null) {
          return false;
        }

        if (isOccupied) {
          return false;
        }

      case PieceType.leaper:
        // Leapers cannot land on pieces
        if (target != null) {
          return false;
        }

        // One step in any direction, or a straight/diagonal leap over a piece
        if (dx > 1 || dy > 1) {
          final isStraightOrDiagonalLeap =
              (dx == 0 || dx == 2) && (dy == 0 || dy == 2);
          if (!isStraightOrDiagonalLeap) {
            return false;
          }
          final midSquare = getSquareByXY(
            (from.x + to.x) ~/ 2,
            (from.y + to.y) ~/ 2,
          );
          if (midSquare?.pieceId == null) {
            return false;
          }
        }

      case PieceType.thrower:
        if (dx > 1 || dy > 1 || isOccupied) {
          return false;
        }

      case PieceType.charger:
        // Orthogonal only, and always as far as it can go
        if (dx != 0 && dy != 0) {
          return false;
        }
        final end = _chargeEnd(
          from,
          piece.owner,
          (to.x - from.x).sign,
          (to.y - from.y).sign,
        );
        if (end == null || end.x != to.x || end.y != to.y) {
          return false;
        }

      case PieceType.hook:
        if (dx + dy != 1 || isOccupied) {
          return false;
        }
    }

    return target == null || target.owner != piece.owner;
  }

  /// Where [owner]'s charger on [from] stops when it runs in the direction ([stepX], [stepY]),
  /// or null if it cannot move that way. An enemy on the end square gets shoved.
  ShoveSquare? _chargeEnd(
    ShoveSquare from,
    IPlayer owner,
    int stepX,
    int stepY,
  ) {
    ShoveSquare? end;
    for (
      var x = from.x + stepX, y = from.y + stepY;
      !isOutOfBounds(x, y);
      x += stepX, y += stepY
    ) {
      final square = getSquareByXY(x, y)!;
      final piece = pieceOn(square);
      if (piece == null) {
        end = square;
        continue;
      }

      // An enemy is only charged into if it has room to slide back
      final canShove =
          piece.owner != owner &&
          piece.pieceType != PieceType.blocker &&
          getSquareByXY(x + stepX, y + stepY)?.pieceId == null;
      return canShove ? square : end;
    }
    return end;
  }

  /// Where the enemy on [to] ends up when a charger runs there from [from];
  /// a square off the board means it is shoved out of the game.
  (int x, int y) chargeShoveTarget(ShoveSquare from, ShoveSquare to) {
    final stepX = (to.x - from.x).sign;
    final stepY = (to.y - from.y).sign;
    var x = to.x + stepX;
    var y = to.y + stepY;
    while (!isOutOfBounds(x, y) && getSquareByXY(x, y)!.pieceId == null) {
      x += stepX;
      y += stepY;
    }
    // Stops in front of the piece that blocks it
    return isOutOfBounds(x, y) ? (x, y) : (x - stepX, y - stepY);
  }

  void _addPieceToSquare(int x, int y, ShovePiece shovePiece) {
    final piece = shovePiece;
    getSquareByXY(x, y)?.pieceId = shovePiece.id;
    pieces[shovePiece.id] = piece;
  }

  ShoveSquare? getSquareByXY(int x, int y) {
    if (isOutOfBounds(x, y)) return null;
    return squares[x * totalNumberOfColumns + y];
  }

  bool isOutOfBounds(int x, int y) {
    //Edges are a dead zone
    return x < 0 ||
        x > totalNumberOfRows - 1 ||
        y < 0 ||
        y > totalNumberOfColumns - 1;
  }

  static Future<ShoveGameMove> isolatedAiMove(ShoveGame shoveGame) async {
    final aiMove = await (shoveGame.currentPlayersTurn as IAi).makeMove(
      shoveGame,
    );
    return aiMove;
  }

  Future<AudioAssets?> procceedGameState() async {
    if (currentPlayersTurn is IAi && isGameOver == false) {
      final aiMove = currentPlayersTurn is MinMaxAi
          ? await isolatedAiMove(this)
          : await (currentPlayersTurn as IAi).makeMove(this);

      final convertIsolatedAiMoveToActualMove = ShoveGameMove(
        getSquareByXY(aiMove.oldSquare.x, aiMove.oldSquare.y)!,
        getSquareByXY(aiMove.newSquare.x, aiMove.newSquare.y)!,
        currentPlayersTurn,
        throwerSquare: getSquareByXY(
          aiMove.throwerSquare?.x ?? -9999,
          aiMove.throwerSquare?.y ?? -9999,
        ),
      );

      final audioToPlay = move(convertIsolatedAiMoveToActualMove);
      return audioToPlay;
    }

    return null;
  }

  AudioAssets? move(ShoveGameMove shoveGameMove) {
    // you cannot move into your own pieces, so we can safely assume that this is always an opponent
    final opponentSquare = shoveGameMove.newSquare;
    AudioAssets? audioToPlay;

    final oldSquarePiece = pieceOn(shoveGameMove.oldSquare);

    shoveGameMove.captureStateBefore(this);

    if (opponentSquare.pieceId != null &&
        oldSquarePiece?.pieceType == PieceType.shover) {
      final shoveDirection = calculateShoveDirection(
        shoveGameMove.oldSquare,
        shoveGameMove.newSquare,
      );
      if (shoveDirection == null) {
        final playerName = oldSquarePiece?.owner.playerName;
        throw Exception('$playerName made an invalid move!');
      }

      final (dx, dy) = switch (shoveDirection) {
        ShoveDirection.xPositive => (1, 0),
        ShoveDirection.xNegative => (-1, 0),
        ShoveDirection.yPositive => (0, 1),
        ShoveDirection.yNegative => (0, -1),
      };
      audioToPlay = shoveGameMove.shove(
        opponentSquare.x + dx,
        opponentSquare.y + dy,
        opponentSquare,
        this,
      );
    }

    if (opponentSquare.pieceId != null &&
        oldSquarePiece?.pieceType == PieceType.charger) {
      final (x, y) = chargeShoveTarget(shoveGameMove.oldSquare, opponentSquare);
      audioToPlay = shoveGameMove.shove(x, y, opponentSquare, this);
    }

    if (oldSquarePiece?.pieceType == PieceType.leaper &&
        shoveGameMove.shoveGameMoveType != ShoveGameMoveType.thrown) {
      shoveGameMove.performLeap(this);
    }

    if (shoveGameMove.shoveGameMoveType == ShoveGameMoveType.thrown) {
      audioToPlay = shoveGameMove.throwPiece(this);
    } else {
      shoveGameMove.movePiece(this);
      audioToPlay ??= AudioAssets.move;
    }

    shoveGameMove.revertIncapacition(this);

    // Applied after the stun wears off, so the charger sits out its next turn
    if (shoveGameMove.shovedPiece != null &&
        oldSquarePiece?.pieceType == PieceType.charger) {
      oldSquarePiece!.isIncapacitated = true;
    }

    currentPlayersTurn = getOpponent(currentPlayersTurn);

    allMadeMoves.add(shoveGameMove);
    checkIfGameIsOver();
    return audioToPlay;
    //printBoard();
  }

  ShoveDirection? calculateShoveDirection(
    ShoveSquare oldSquare,
    ShoveSquare newSquare,
  ) {
    if (newSquare.x > oldSquare.x) {
      return ShoveDirection.xPositive;
    } else if (newSquare.x < oldSquare.x) {
      return ShoveDirection.xNegative;
    }

    if (newSquare.y > oldSquare.y) {
      return ShoveDirection.yPositive;
    } else if (newSquare.y < oldSquare.y) {
      return ShoveDirection.yNegative;
    }

    return null;
  }

  bool shoveResultsInCollision(ShoveDirection direction, int x, int y) {
    return switch (direction) {
      ShoveDirection.xPositive => getSquareByXY(x + 1, y)?.pieceId != null,
      ShoveDirection.xNegative => getSquareByXY(x - 1, y)?.pieceId != null,
      ShoveDirection.yPositive => getSquareByXY(x, y + 1)?.pieceId != null,
      ShoveDirection.yNegative => getSquareByXY(x, y - 1)?.pieceId != null,
    };
  }

  ({bool isOver, IPlayer? winner}) checkIfGameIsOver() {
    gameOverState = null;
    IPlayer? winner;
    GameOverReason? reason;

    if (_hasShoverInGoal(player1, player1GoalShoveSquares)) {
      (winner, reason) = (player1, GameOverReason.reachedGoal);
    } else if (_hasShoverInGoal(player2, player2GoalShoveSquares)) {
      (winner, reason) = (player2, GameOverReason.reachedGoal);
    } else if (!_hasShovers(player1)) {
      (winner, reason) = (player2, GameOverReason.noShoversLeft);
    } else if (!_hasShovers(player2)) {
      (winner, reason) = (player1, GameOverReason.noShoversLeft);
    } else if (!hasAnyLegalMove()) {
      (winner, reason) = (
        getOpponent(currentPlayersTurn),
        GameOverReason.noLegalMoves,
      );
    } else if (_hasRepeatedLastThreeMoves(player1) &&
        _hasRepeatedLastThreeMoves(player2)) {
      reason = GameOverReason.repetition;
    }

    gameOverReason = reason;
    gameOverState = (winner: winner, isOver: reason != null);

    return gameOverState!;
  }

  bool _hasShoverInGoal(IPlayer player, List<ShoveSquare> goalSquares) {
    for (final square in goalSquares) {
      final piece = pieceOn(square);
      if (piece != null &&
          piece.pieceType == PieceType.shover &&
          piece.owner == player) {
        return true;
      }
    }
    return false;
  }

  bool _hasShovers(IPlayer player) {
    for (final piece in pieces.values) {
      if (piece.pieceType == PieceType.shover && piece.owner == player) {
        return true;
      }
    }
    return false;
  }

  /// Whether the player's last three moves (newest first) were played before as consecutive moves.
  bool _hasRepeatedLastThreeMoves(IPlayer player) {
    if (allMadeMoves.length < 9) {
      return false;
    }

    ShoveGameMove? newest, second, third;
    for (var i = allMadeMoves.length - 1; i >= 0 && third == null; i--) {
      final move = allMadeMoves[i];
      if (move.madeBy != player) continue;
      if (newest == null) {
        newest = move;
      } else if (second == null) {
        second = move;
      } else {
        third = move;
      }
    }
    if (third == null) {
      return false;
    }

    // Chronological window of the player's moves ending before their newest move
    ShoveGameMove? twoBefore, oneBefore;
    for (final move in allMadeMoves) {
      if (move.madeBy != player) continue;
      if (identical(move, newest)) break;
      if (twoBefore == newest && oneBefore == second && move == third) {
        return true;
      }
      twoBefore = oneBefore;
      oneBefore = move;
    }
    return false;
  }

  bool _isCurrentPlayer(IPlayer? player) => player == currentPlayersTurn;

  /// All legal moves for the piece on [from]. For an opponent's piece this is
  /// every way the current player can throw it.
  List<ShoveGameMove> getLegalMovesFrom(ShoveSquare from) {
    final moves = <ShoveGameMove>[];
    _collectLegalMoves(from, moves);
    return moves;
  }

  bool hasLegalMovesFrom(ShoveSquare from) => _collectLegalMoves(from, null);

  /// Adds the legal moves for the piece on [from] to [moves], or only looks for
  /// one when [moves] is null. Returns whether there is a legal move.
  bool _collectLegalMoves(ShoveSquare from, List<ShoveGameMove>? moves) {
    final piece = pieceOn(from);
    if (piece == null || isGameOver) return false;

    var found = false;

    if (!_isCurrentPlayer(piece.owner)) {
      for (final throwerSquare in getAllNeighborSquares(from)) {
        if (!_canThrow(throwerSquare, from)) continue;
        for (final target in getAllNeighborSquares(throwerSquare)) {
          if (target.pieceId != null) continue;
          if (moves == null) return true;
          found = true;
          moves.add(
            ShoveGameMove(
              from,
              target,
              currentPlayersTurn,
              throwerSquare: throwerSquare,
            ),
          );
        }
      }
      return _collectPulls(from, moves) || found;
    }

    if (!piece.isIncapacitated) {
      if (piece.pieceType == PieceType.charger) {
        for (final (dx, dy) in _orthogonalDirections) {
          final end = _chargeEnd(from, piece.owner, dx, dy);
          if (end == null) continue;
          if (moves == null) return true;
          found = true;
          moves.add(ShoveGameMove(from, end, currentPlayersTurn));
        }
      } else {
        final reach = switch (piece.pieceType) {
          PieceType.shover || PieceType.thrower || PieceType.hook => 1,
          PieceType.blocker || PieceType.leaper => 2,
          PieceType.charger => 0,
        };
        for (final (dx, dy) in _directions) {
          for (var step = 1; step <= reach; step++) {
            final target = getSquareByXY(
              from.x + dx * step,
              from.y + dy * step,
            );
            if (target == null) break;
            if (!_isLegalStep(piece, from, target)) continue;
            if (moves == null) return true;
            found = true;
            moves.add(ShoveGameMove(from, target, currentPlayersTurn));
          }
        }

        if (piece.pieceType == PieceType.shover) {
          final hop = getSquareByXY(
            from.x + 2 * forwardDirectionOf(piece.owner),
            from.y,
          );
          if (hop != null && _isLegalStep(piece, from, hop)) {
            if (moves == null) return true;
            found = true;
            moves.add(ShoveGameMove(from, hop, currentPlayersTurn));
          }
        }
      }
    }
    return _collectPulls(from, moves) || found;
  }

  /// Adds the ways a hook can pull the piece on [from], or only looks for one
  /// when [moves] is null. Returns whether there is one.
  bool _collectPulls(ShoveSquare from, List<ShoveGameMove>? moves) {
    var found = false;
    for (final (dx, dy) in _orthogonalDirections) {
      for (var step = 1; step <= _hookRange; step++) {
        final hook = getSquareByXY(from.x + dx * step, from.y + dy * step);
        if (hook == null) break;
        if (hook.pieceId == null) continue;

        // Only the first piece on the line can reach us
        final landing = _pullLanding(hook, from);
        if (landing != null) {
          if (moves == null) return true;
          found = true;
          moves.add(
            ShoveGameMove(
              from,
              landing,
              currentPlayersTurn,
              throwerSquare: hook,
            ),
          );
        }
        break;
      }
    }
    return found;
  }

  static const _directions = [
    (-1, -1), (-1, 0), (-1, 1), //
    (0, -1), (0, 1), //
    (1, -1), (1, 0), (1, 1),
  ];

  static const _orthogonalDirections = [(-1, 0), (0, -1), (0, 1), (1, 0)];

  List<ShoveGameMove> getAllLegalMoves() {
    final moves = <ShoveGameMove>[];
    for (final square in squares) {
      if (square.pieceId != null) _collectLegalMoves(square, moves);
    }
    return moves;
  }

  /// The legal moves of the current player's shovers and chargers, the only pieces that
  /// can score or eliminate; much cheaper than [getAllLegalMoves].
  List<ShoveGameMove> getLegalAttackerMoves() {
    final moves = <ShoveGameMove>[];
    for (final square in squares) {
      final piece = pieceOn(square);
      if (piece != null &&
          (piece.pieceType == PieceType.shover ||
              piece.pieceType == PieceType.charger) &&
          _isCurrentPlayer(piece.owner)) {
        _collectLegalMoves(square, moves);
      }
    }
    return moves..removeWhere((move) => move.throwerSquare != null);
  }

  bool hasAnyLegalMove() {
    for (final square in squares) {
      if (square.pieceId != null && _collectLegalMoves(square, null)) {
        return true;
      }
    }
    return false;
  }

  void undoLastMove() {
    if (allMadeMoves.isEmpty) return;

    final lastMove = allMadeMoves.removeLast();

    lastMove.revertMove(this);

    currentPlayersTurn = lastMove.madeBy == player1 ? player1 : player2;
  }

  ({bool isValid, ShoveSquare? throwerSquare}) shoveSquareIsValidTargetForThrow(
    ShoveSquare square,
  ) {
    final squarePiece = pieceOn(square);

    if (squarePiece == null || _isCurrentPlayer(squarePiece.owner)) {
      return (isValid: false, throwerSquare: null);
    }

    for (final neighbor in getAllNeighborSquares(square)) {
      final piece = pieceOn(neighbor);
      if (piece != null &&
          piece.pieceType == PieceType.thrower &&
          _isCurrentPlayer(piece.owner)) {
        return (isValid: true, throwerSquare: neighbor);
      }
    }
    return (isValid: false, throwerSquare: null);
  }

  List<ShoveSquare> getAllNeighborSquares(ShoveSquare square) =>
      _neighbors[square.x * totalNumberOfColumns + square.y];

  List<ShoveSquare> _computeNeighborSquares(ShoveSquare square) {
    List<ShoveSquare> neighbors = [];

    for (int x = square.x - 1; x <= square.x + 1; x++) {
      for (int y = square.y - 1; y <= square.y + 1; y++) {
        if (x == square.x && y == square.y) continue;

        final neighbor = getSquareByXY(x, y);
        if (neighbor != null) {
          neighbors.add(neighbor);
        }
      }
    }

    return neighbors;
  }

  late final List<IPlayer> players = List.unmodifiable([player1, player2]);

  /// The player whose turn comes after [player].
  IPlayer getOpponent(IPlayer player) => player == player1 ? player2 : player1;

  /// Squares where a shover owned by [player] wins the game.
  List<ShoveSquare> goalSquaresOf(IPlayer player) =>
      player == player1 ? player1GoalShoveSquares : player2GoalShoveSquares;

  /// Row a shover owned by [player] has to reach to win the game.
  int goalRowOf(IPlayer player) =>
      player == player1 ? _player1GoalRow : _player2GoalRow;

  /// Row step a shover owned by [player] takes when moving forward.
  int forwardDirectionOf(IPlayer player) => player == player1 ? -1 : 1;

  int getSquaresDistanceToGoal(IPlayer owner, ShoveSquare square) =>
      (goalRowOf(owner) - square.x).abs();

  static const _hashModulus = 0x1FFFFFFFFFFF;

  /// Identifies the position (pieces, stuns and side to move) for search caches.
  /// Kept below 2^53 so it is exact on the web too.
  int get positionKey {
    final pieceKinds = PieceType.values.length;
    var hash = currentPlayersTurn == player1 ? 1 : 2;
    for (final square in squares) {
      final piece = pieceOn(square);
      final code = piece == null
          ? 0
          : 1 +
                piece.pieceType.index +
                (piece.owner == player1 ? 0 : pieceKinds) +
                (piece.isIncapacitated ? 2 * pieceKinds : 0);
      hash = (hash * 31 + code) % _hashModulus;
    }
    return hash;
  }
}
