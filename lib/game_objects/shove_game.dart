import 'dart:collection';

import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/ai/min_max_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
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

  final IPlayer player1;
  final IPlayer player2;

  IPlayer currentPlayersTurn;
  ({IPlayer? winner, bool isOver})? gameOverState;
  GameOverReason? gameOverReason;

  bool get isGameOver => gameOverState?.isOver == true;
  bool get isDraw =>
      gameOverState?.winner == null && gameOverState?.isOver == true;

  final HashMap<(int x, int y), ShoveSquare> board;

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

      for (
        int currentCol = 0;
        currentCol < totalNumberOfColumns;
        currentCol++
      ) {
        getSquareByXY(1, currentCol)?.pieceId = pieces.values
            .where(
              (element) =>
                  element.owner == player2 &&
                  element.pieceType == PieceType.shover,
            )
            .map((e) => e.id)
            .toList()[currentCol];
        getSquareByXY(6, currentCol)?.pieceId = pieces.values
            .where(
              (element) =>
                  element.owner == player1 &&
                  element.pieceType == PieceType.shover,
            )
            .map((e) => e.id)
            .toList()[currentCol];
      }

      for (var col = 0; col < backRank.length; col++) {
        _addPieceToSquare(7, col, backRank[col](player1));
        _addPieceToSquare(0, col, backRank[col](player2));
      }
    }

    for (int currentCol = 0; currentCol < totalNumberOfColumns; currentCol++) {
      player1GoalShoveSquares.add(getSquareByXY(0, currentCol)!);
      player2GoalShoveSquares.add(
        getSquareByXY(ShoveGame.totalNumberOfColumns - 1, currentCol)!,
      );
    }
  }

  factory ShoveGame.fromDto(ShoveGameStateDto dto) {
    final player1 = IPlayer.fromDto(dto.player1);
    final player2 = IPlayer.fromDto(dto.player2);

    final board = dto.board.map(
      (key, value) => MapEntry((
        int.parse(key.split(',')[0]),
        int.parse(key.split(',')[1]),
      ), ShoveSquare.fromDto(value)),
    );

    final pieces = dto.pieces.map(
      (key, value) => MapEntry(key, ShovePiece.fromDto(value)),
    );

    final allMadeMoves = dto.allMadeMoves
        .map((e) => ShoveGameMove.fromDto(e))
        .toList();

    final currentPlayersTurn = IPlayer.fromDto(dto.currentPlayersTurn);

    final gameOverState = dto.gameOverState != null
        ? (
            winner: IPlayer.fromDto(dto.gameOverState!.winner!),
            isOver: dto.gameOverState!.isOver,
          )
        : null;

    return ShoveGame(
        player1,
        player2,
        customBoard: HashMap.from(board),
        customPieces: pieces,
        currentPlayersTurn: currentPlayersTurn,
      )
      ..allMadeMoves.addAll(allMadeMoves)
      ..gameOverState = gameOverState;
  }

  /// Symmetric back rank so neither flank is stronger than the other.
  static const List<ShovePiece Function(IPlayer)> backRank = [
    ShovePiece.blocker,
    ShovePiece.leaper,
    ShovePiece.thrower,
    ShovePiece.leaper,
    ShovePiece.leaper,
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
    final throwerPiece = pieces[thrower.pieceId];
    final thrownFromSquarePiece = pieces[thrownFromSquare.pieceId];

    final throwerIsThrowerAndNotIncapacitated =
        throwerPiece?.pieceType == PieceType.thrower &&
        throwerPiece?.isIncapacitated == false;
    final throwerBelongsToCurrentPlayer =
        throwerPiece?.owner == currentPlayersTurn;
    final thrownPieceBelongsToOpponent =
        thrownFromSquarePiece?.owner != currentPlayersTurn;
    final thrownPieceIsNotIncapacitated =
        thrownFromSquarePiece?.isIncapacitated == false;
    final thrownToSquareIsNotOccupied = thrownToSquare.pieceId == null;
    final thrownPieceIsNextToFriendlyBlocker =
        getAllNeighborSquares(thrownFromSquare).any((element) {
          final piece = pieces[element.pieceId];
          return piece?.pieceType == PieceType.blocker &&
              piece?.owner != currentPlayersTurn;
        });

    final throwerIsNotThrowingItself = thrower != thrownFromSquare;

    if (isOutOfBounds(thrownToSquare.x, thrownToSquare.y)) {
      return false;
    }
    if (thrownPieceIsNextToFriendlyBlocker) {
      return false;
    }
    if (!throwerIsThrowerAndNotIncapacitated) {
      return false;
    }
    if (!throwerBelongsToCurrentPlayer || !thrownPieceBelongsToOpponent) {
      return false;
    }
    if (!throwerIsNotThrowingItself) {
      return false;
    }
    if (!thrownPieceIsNotIncapacitated) {
      return false;
    }

    if ((thrower.x - thrownToSquare.x).abs() > 1) {
      return false;
    }

    if ((thrower.y - thrownToSquare.y).abs() > 1) {
      return false;
    }

    if (thrownFromSquarePiece?.pieceType == PieceType.blocker) {
      return false;
    }

    if (!thrownToSquareIsNotOccupied) {
      return false;
    }

    return true;
  }

  bool validateMove(ShoveGameMove shoveGameMove) {
    final oldSquarePiece = pieces[shoveGameMove.oldSquare.pieceId];
    final newSquarePiece = pieces[shoveGameMove.newSquare.pieceId];

    if (isGameOver) {
      return false;
    }

    if (shoveGameMove.oldSquare.x == shoveGameMove.newSquare.x &&
        shoveGameMove.oldSquare.y == shoveGameMove.newSquare.y) {
      return false;
    }

    if (shoveGameMove.oldSquare.pieceId == null) {
      return false;
    }

    if (oldSquarePiece?.isIncapacitated ?? false) {
      return false;
    }

    if (shoveGameMove.shoveGameMoveType == ShoveGameMoveType.thrown) {
      return validateThrow(
        shoveGameMove.throwerSquare!,
        shoveGameMove.oldSquare,
        shoveGameMove.newSquare,
      );
    }

    final pieceToMoveBelongsToCurrentPlayer =
        oldSquarePiece?.owner == currentPlayersTurn;

    if (!pieceToMoveBelongsToCurrentPlayer) {
      return false;
    }

    if (isOutOfBounds(shoveGameMove.newSquare.x, shoveGameMove.newSquare.y)) {
      return false;
    }

    switch (oldSquarePiece!.pieceType) {
      case PieceType.shover:
        if ((shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x).abs() > 1) {
          return false;
        }

        if ((shoveGameMove.oldSquare.y - shoveGameMove.newSquare.y).abs() > 1) {
          return false;
        }

        // Shovers cannot move diagonally
        if ((shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x).abs() > 0 &&
            (shoveGameMove.oldSquare.y - shoveGameMove.newSquare.y).abs() > 0) {
          return false;
        }

        // Shovers cannot move backwards
        if (oldSquarePiece.owner.isWhite == true) {
          if (shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x < 0) {
            return false;
          }
        } else {
          if (shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x > 0) {
            return false;
          }
        }

        // Shovers cannot shove blockers
        if (newSquarePiece?.pieceType == PieceType.blocker) {
          return false;
        }

        if ((shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x).abs() > 0 &&
            (shoveGameMove.oldSquare.y - shoveGameMove.newSquare.y).abs() > 0) {
          return false;
        }

        var direction = calculateShoveDirection(
          shoveGameMove.oldSquare,
          shoveGameMove.newSquare,
        );
        if (direction == null) {
          return false;
        }

        if (getSquareByXY(
              shoveGameMove.newSquare.x,
              shoveGameMove.newSquare.y,
            )?.pieceId !=
            null) {
          // Shovers cannot shove if it results in a collision with another piece
          if (shoveResultsInCollision(
            direction,
            shoveGameMove.newSquare.x,
            shoveGameMove.newSquare.y,
          )) {
            return false;
          }
        }

      case PieceType.blocker:
        if ((shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x).abs() > 0 &&
            (shoveGameMove.oldSquare.y - shoveGameMove.newSquare.y).abs() > 0) {
          return false;
        }

        if ((shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x).abs() > 2 ||
            (shoveGameMove.oldSquare.y - shoveGameMove.newSquare.y).abs() > 2) {
          return false;
        }

        if ((shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x).abs() > 1 ||
            (shoveGameMove.oldSquare.y - shoveGameMove.newSquare.y).abs() > 1) {
          // Check if blocker is attempting to jump over a piece
          int midX =
              (shoveGameMove.oldSquare.x + shoveGameMove.newSquare.x) ~/ 2;
          int midY =
              ((shoveGameMove.oldSquare.y + shoveGameMove.newSquare.y) ~/ 2);
          ShoveSquare midSquare = getSquareByXY(midX, midY)!;
          if (midSquare.pieceId != null) {
            return false;
          }
        }

        if (getSquareByXY(
              shoveGameMove.newSquare.x,
              shoveGameMove.newSquare.y,
            )?.pieceId !=
            null) {
          return false;
        }
      case PieceType.leaper:
        // Leapers cannot land on pieces
        if (newSquarePiece != null) {
          return false;
        }

        final dx = (shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x)
            .abs();
        final dy = (shoveGameMove.oldSquare.y - shoveGameMove.newSquare.y)
            .abs();

        // One step in any direction, or a straight/diagonal leap over a piece
        if (dx > 1 || dy > 1) {
          final isStraightOrDiagonalLeap =
              (dx == 0 || dx == 2) && (dy == 0 || dy == 2);
          if (!isStraightOrDiagonalLeap) {
            return false;
          }
          final midSquare = getSquareByXY(
            (shoveGameMove.oldSquare.x + shoveGameMove.newSquare.x) ~/ 2,
            (shoveGameMove.oldSquare.y + shoveGameMove.newSquare.y) ~/ 2,
          );
          if (midSquare?.pieceId == null) {
            return false;
          }
        }

      case PieceType.thrower:
        if ((shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x).abs() > 1 ||
            (shoveGameMove.oldSquare.y - shoveGameMove.newSquare.y).abs() > 1) {
          return false;
        }

        if (getSquareByXY(
              shoveGameMove.newSquare.x,
              shoveGameMove.newSquare.y,
            )?.pieceId !=
            null) {
          return false;
        }
    }

    if (newSquarePiece?.owner == oldSquarePiece.owner) {
      return false;
    }

    return true;
  }

  void _addPieceToSquare(int x, int y, ShovePiece shovePiece) {
    final piece = shovePiece;
    getSquareByXY(x, y)?.pieceId = shovePiece.id;
    pieces[shovePiece.id] = piece;
  }

  ShoveSquare? getSquareByXY(int x, int y) {
    return board[(x, y)];
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
    var opponentSquare = shoveGameMove.newSquare;
    AudioAssets? audioToPlay;

    final oldSquarePiece = pieces[shoveGameMove.oldSquare.pieceId];

    shoveGameMove.captureStateBefore(this);

    if (opponentSquare.pieceId != null &&
        oldSquarePiece?.pieceType == PieceType.shover) {
      var shoveDirection = calculateShoveDirection(
        shoveGameMove.oldSquare,
        shoveGameMove.newSquare,
      );
      if (shoveDirection == null) {
        final playerName = oldSquarePiece?.owner.playerName;
        throw Exception('$playerName made an invalid move!');
      }

      switch (shoveDirection) {
        case ShoveDirection.xPositive:
          audioToPlay = shoveGameMove.shove(
            shoveGameMove.newSquare.x + 1,
            shoveGameMove.newSquare.y,
            opponentSquare,
            this,
          );
        case ShoveDirection.xNegative:
          audioToPlay = shoveGameMove.shove(
            shoveGameMove.newSquare.x - 1,
            shoveGameMove.newSquare.y,
            opponentSquare,
            this,
          );
        case ShoveDirection.yPositive:
          audioToPlay = shoveGameMove.shove(
            shoveGameMove.newSquare.x,
            shoveGameMove.newSquare.y + 1,
            opponentSquare,
            this,
          );
        case ShoveDirection.yNegative:
          audioToPlay = shoveGameMove.shove(
            shoveGameMove.newSquare.x,
            shoveGameMove.newSquare.y - 1,
            opponentSquare,
            this,
          );
      }
    }

    if (oldSquarePiece?.pieceType == PieceType.leaper) {
      shoveGameMove.performLeap(this);
    }

    if (shoveGameMove.shoveGameMoveType == ShoveGameMoveType.thrown) {
      audioToPlay = shoveGameMove.throwPiece(this);
    } else {
      shoveGameMove.movePiece(this);
      audioToPlay ??= AudioAssets.move;
    }

    shoveGameMove.revertIncapacition(this);

    currentPlayersTurn = currentPlayersTurn.isWhite ? player2 : player1;

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
    bool listEquals<T>(List<T> list1, List<T> list2) {
      if (list1.length != list2.length) return false;
      for (int i = 0; i < list1.length; i++) {
        if (list1[i] != list2[i]) return false;
      }
      return true;
    }

    bool checkIfPlayerHasRepeatedSameMoveThreeTimes(IPlayer player) {
      if (allMadeMoves.length < 9) {
        return false;
      }

      var playerMoves = allMadeMoves
          .where((move) => move.madeBy == player)
          .toList();
      if (playerMoves.length < 3) {
        return false;
      }

      var lastThreeMoves = playerMoves.reversed.take(3).toList();

      for (int i = 0; i < playerMoves.length - 3; i++) {
        var sequence = playerMoves.getRange(i, i + 3);
        if (listEquals(sequence.toList(), lastThreeMoves)) {
          return true;
        }
      }
      return false;
    }

    bool hasShoverInGoal(IPlayer player, List<ShoveSquare> goalSquares) =>
        goalSquares.any((element) {
          final piece = pieces[element.pieceId];
          return piece?.owner == player && piece?.pieceType == PieceType.shover;
        });

    bool hasShoversLeft(IPlayer player) => pieces.values.any(
      (piece) => piece.owner == player && piece.pieceType == PieceType.shover,
    );

    gameOverState = null;
    IPlayer? winner;
    GameOverReason? reason;

    if (hasShoverInGoal(player1, player1GoalShoveSquares)) {
      (winner, reason) = (player1, GameOverReason.reachedGoal);
    } else if (hasShoverInGoal(player2, player2GoalShoveSquares)) {
      (winner, reason) = (player2, GameOverReason.reachedGoal);
    } else if (!hasShoversLeft(player1)) {
      (winner, reason) = (player2, GameOverReason.noShoversLeft);
    } else if (!hasShoversLeft(player2)) {
      (winner, reason) = (player1, GameOverReason.noShoversLeft);
    } else if (!hasAnyLegalMove()) {
      (winner, reason) = (
        getOpponent(currentPlayersTurn),
        GameOverReason.noLegalMoves,
      );
    } else if (checkIfPlayerHasRepeatedSameMoveThreeTimes(player1) &&
        checkIfPlayerHasRepeatedSameMoveThreeTimes(player2)) {
      reason = GameOverReason.repetition;
    }

    gameOverReason = reason;
    gameOverState = (winner: winner, isOver: reason != null);

    return gameOverState!;
  }

  /// All legal moves for the piece on [from]. For an opponent's piece this is
  /// every way the current player can throw it.
  List<ShoveGameMove> getLegalMovesFrom(ShoveSquare from) {
    final piece = pieces[from.pieceId];
    if (piece == null) return const [];

    final legals = <ShoveGameMove>[];

    if (piece.owner == currentPlayersTurn) {
      // No piece moves further than two squares.
      for (var x = from.x - 2; x <= from.x + 2; x++) {
        for (var y = from.y - 2; y <= from.y + 2; y++) {
          final target = getSquareByXY(x, y);
          if (target == null) continue;
          final move = ShoveGameMove(from, target, currentPlayersTurn);
          if (validateMove(move)) legals.add(move);
        }
      }
      return legals;
    }

    for (final throwerSquare in getAllNeighborSquares(from)) {
      final thrower = pieces[throwerSquare.pieceId];
      if (thrower?.pieceType != PieceType.thrower ||
          thrower?.owner != currentPlayersTurn) {
        continue;
      }
      for (final target in getAllNeighborSquares(throwerSquare)) {
        final move = ShoveGameMove(
          from,
          target,
          currentPlayersTurn,
          throwerSquare: throwerSquare,
        );
        if (validateMove(move)) legals.add(move);
      }
    }
    return legals;
  }

  List<ShoveGameMove> getAllLegalMoves() => [
    for (final square in board.values)
      if (square.pieceId != null) ...getLegalMovesFrom(square),
  ];

  bool hasAnyLegalMove() => board.values.any(
    (square) => square.pieceId != null && getLegalMovesFrom(square).isNotEmpty,
  );

  void undoLastMove() {
    if (allMadeMoves.isEmpty) return;

    final lastMove = allMadeMoves.removeLast();

    lastMove.revertMove(this);

    currentPlayersTurn = lastMove.madeBy.isWhite ? player1 : player2;
  }

  ({bool isValid, ShoveSquare? throwerSquare}) shoveSquareIsValidTargetForThrow(
    ShoveSquare square,
  ) {
    final squarePiece = pieces[square.pieceId];

    if (square.pieceId == null || squarePiece?.owner == currentPlayersTurn) {
      return (isValid: false, throwerSquare: null);
    }

    final neighbors = getAllNeighborSquares(square);

    try {
      final ShoveSquare throwerSquare = neighbors.firstWhere((element) {
        final piece = pieces[element.pieceId];

        final isOpponentsThrower =
            piece?.pieceType == PieceType.thrower &&
            piece?.owner != currentPlayersTurn;
        final isMyThrowerAndTargetIsOpponentsPiece =
            piece?.pieceType == PieceType.thrower &&
            piece?.owner == currentPlayersTurn &&
            squarePiece?.owner != currentPlayersTurn;

        return !isOpponentsThrower && isMyThrowerAndTargetIsOpponentsPiece;
      }, orElse: () => throw Exception('No valid neighbor found'));

      return (isValid: true, throwerSquare: throwerSquare);
    } catch (e) {
      return (isValid: false, throwerSquare: null);
    }
  }

  List<ShoveSquare> getAllNeighborSquares(ShoveSquare square) {
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

  IPlayer getOpponent(IPlayer player) {
    return player == player1 ? player2 : player1;
  }

  int getSquaresDistanceToGoal(IPlayer owner, ShoveSquare square) {
    if (owner == player1) {
      return (player1GoalShoveSquares.first.x - square.x).abs();
    } else {
      return (player2GoalShoveSquares.first.x - square.x).abs();
    }
  }

  int calculateBoardStateHash() {
    var hash = 7;

    for (var piece in pieces.values) {
      hash = 31 * hash + piece.hashCode;
      hash = 31 * hash + (piece.isIncapacitated ? 1 : 0);
    }

    hash = 31 * hash + currentPlayersTurn.hashCode;

    if (isGameOver) {
      hash = 31 * hash + (isGameOver ? 1 : 0);
    }
    if (isDraw) {
      hash = 31 * hash + (isDraw ? 1 : 0);
    }

    for (var square in board.values) {
      hash = 31 * hash + square.hashCode;
    }

    return hash;
  }
}
