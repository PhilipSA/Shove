import 'dart:collection';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/ai/min_max_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_direction.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_square.dart';

class ShoveGame {
  final List<ShovePiece> pieces;
  final List<ShoveGameMove> allMadeMoves = [];

  static const int totalNumberOfRows = 10;
  static const int totalNumberOfColumns = 10;

  final IPlayer player1;
  final IPlayer player2;

  IPlayer currentPlayersTurn;
  ({IPlayer? winner, bool isOver})? gameOverState;

  bool get isGameOver => gameOverState?.isOver == true;
  bool get isDraw =>
      gameOverState?.winner == null && gameOverState?.isOver == true;

  final HashMap<(int x, int y), ShoveSquare> board;

  final List<ShoveSquare> player1GoalShoveSquares = [];
  final List<ShoveSquare> player2GoalShoveSquares = [];

  ShoveGame(this.player1, this.player2,
      {HashMap<(int x, int y), ShoveSquare>? customBoard,
      List<ShovePiece>? customPieces,
      IPlayer? currentPlayersTurn})
      : currentPlayersTurn = currentPlayersTurn ?? player1,
        pieces = customPieces ?? getInitialPieces(player1, player2),
        board = customBoard ?? HashMap() {
    if (customBoard == null) {
      for (int i = 0; i < totalNumberOfRows; i++) {
        for (int j = 0; j < totalNumberOfColumns; j++) {
          ShoveSquare square = ShoveSquare(i, j, null);

          board[(i, j)] = square;
        }
      }

      for (int currentCol = 1;
          currentCol < totalNumberOfColumns - 1;
          currentCol++) {
        getSquareByXY(2, currentCol)?.piece = pieces
            .where((element) =>
                element.owner == player2 &&
                element.pieceType == PieceType.shover)
            .toList()[currentCol];
        getSquareByXY(7, currentCol)?.piece = pieces
            .where((element) =>
                element.owner == player1 &&
                element.pieceType == PieceType.shover)
            .toList()[currentCol];
      }

      _addPieceToSquare(8, 1, ShovePiece.blocker(player1));
      _addPieceToSquare(8, 2, ShovePiece.leaper(player1));
      _addPieceToSquare(8, 3, ShovePiece.thrower(player1));
      _addPieceToSquare(8, 4, ShovePiece.thrower(player1));
      _addPieceToSquare(8, 5, ShovePiece.leaper(player1));
      _addPieceToSquare(8, 6, ShovePiece.thrower(player1));
      _addPieceToSquare(8, 7, ShovePiece.leaper(player1));
      _addPieceToSquare(8, 8, ShovePiece.blocker(player1));

      _addPieceToSquare(1, 1, ShovePiece.blocker(player2));
      _addPieceToSquare(1, 2, ShovePiece.leaper(player2));
      _addPieceToSquare(1, 3, ShovePiece.thrower(player2));
      _addPieceToSquare(1, 4, ShovePiece.thrower(player2));
      _addPieceToSquare(1, 5, ShovePiece.leaper(player2));
      _addPieceToSquare(1, 6, ShovePiece.thrower(player2));
      _addPieceToSquare(1, 7, ShovePiece.leaper(player2));
      _addPieceToSquare(1, 8, ShovePiece.blocker(player2));
    }

    for (int currentCol = 1;
        currentCol < totalNumberOfColumns - 1;
        currentCol++) {
      player1GoalShoveSquares.add(getSquareByXY(1, currentCol)!);
      player2GoalShoveSquares
          .add(getSquareByXY(ShoveGame.totalNumberOfColumns - 2, currentCol)!);
    }
  }

  static List<ShovePiece> getInitialPieces(IPlayer player1, IPlayer player2) {
    final player1Shovers =
        List.generate(9, (index) => ShovePiece.shover(player1));

    final player2Shovers =
        List.generate(9, (index) => ShovePiece.shover(player2));

    return player1Shovers..addAll(player2Shovers);
  }

  bool validateThrow(ShoveSquare thrower, ShoveSquare thrownFromSquare,
      ShoveSquare thrownToSquare) {
    final throwerIsThrowerAndNotIncapacitated =
        thrower.piece?.pieceType == PieceType.thrower &&
            thrower.piece?.isIncapacitated == false;
    final throwerBelongsToCurrentPlayer =
        thrower.piece?.owner == currentPlayersTurn;
    final thrownPieceBelongsToOpponent =
        thrownFromSquare.piece?.owner != currentPlayersTurn;
    final thrownPieceIsNotIncapacitated =
        thrownFromSquare.piece?.isIncapacitated == false;
    final thrownToSquareIsNotOccupied = thrownToSquare.piece == null;
    final thrownPieceIsNextToFriendlyBlocker =
        getAllNeighborSquares(thrownFromSquare).any((element) =>
            element.piece?.pieceType == PieceType.blocker &&
            element.piece?.owner != currentPlayersTurn);

    final throwerIsNotThrowingItself = thrower != thrownFromSquare;

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

    if (getSquareByXY(thrownFromSquare.x, thrownFromSquare.y)
            ?.piece
            ?.pieceType ==
        PieceType.blocker) {
      return false;
    }

    if (!thrownToSquareIsNotOccupied) {
      return false;
    }

    return true;
  }

  bool validateMove(ShoveGameMove shoveGameMove) {
    if (shoveGameMove.oldSquare.x == shoveGameMove.newSquare.x &&
        shoveGameMove.oldSquare.y == shoveGameMove.newSquare.y) {
      return false;
    }

    if (shoveGameMove.oldSquare.piece == null) {
      return false;
    }

    if (shoveGameMove.oldSquare.piece?.isIncapacitated ?? false) {
      return false;
    }

    if (shoveGameMove.shoveGameMoveType == ShoveGameMoveType.thrown) {
      return validateThrow(shoveGameMove.throwerSquare!,
          shoveGameMove.oldSquare, shoveGameMove.newSquare);
    }

    final pieceToMoveBelongsToCurrentPlayer =
        shoveGameMove.oldSquare.piece?.owner == currentPlayersTurn;

    if (!pieceToMoveBelongsToCurrentPlayer) {
      return false;
    }

    if (isOutOfBounds(shoveGameMove.newSquare.x, shoveGameMove.newSquare.y)) {
      return false;
    }

    switch (shoveGameMove.oldSquare.piece!.pieceType) {
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
        if (shoveGameMove.oldSquare.piece?.owner.isWhite == true) {
          if (shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x < 0) {
            return false;
          }
        } else {
          if (shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x > 0) {
            return false;
          }
        }

        // Shovers cannot shove blockers
        if (getSquareByXY(shoveGameMove.newSquare.x, shoveGameMove.newSquare.y)!
                .piece
                ?.pieceType ==
            PieceType.blocker) {
          return false;
        }

        if ((shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x).abs() > 0 &&
            (shoveGameMove.oldSquare.y - shoveGameMove.newSquare.y).abs() > 0) {
          return false;
        }

        var direction = calculateShoveDirection(
            shoveGameMove.oldSquare, shoveGameMove.newSquare);
        if (direction == null) {
          return false;
        }

        if (getSquareByXY(shoveGameMove.newSquare.x, shoveGameMove.newSquare.y)
                ?.piece !=
            null) {
          // Shovers cannot shove if it results in a collision with another piece
          if (shoveResultsInCollision(direction, shoveGameMove.newSquare.x,
              shoveGameMove.newSquare.y)) {
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
          if (midSquare.piece != null) {
            return false;
          }
        }

        if (getSquareByXY(shoveGameMove.newSquare.x, shoveGameMove.newSquare.y)
                ?.piece !=
            null) {
          return false;
        }
      case PieceType.leaper:
        if ((shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x).abs() > 0 &&
            (shoveGameMove.oldSquare.y - shoveGameMove.newSquare.y).abs() > 0) {
          return false;
        }

        // Leapers cannot land on pieces
        if (getSquareByXY(shoveGameMove.newSquare.x, shoveGameMove.newSquare.y)
                ?.piece !=
            null) {
          return false;
        }

        // Check if there is a piece to jump over
        int midX = (shoveGameMove.oldSquare.x + shoveGameMove.newSquare.x) ~/ 2;
        int midY =
            ((shoveGameMove.oldSquare.y + shoveGameMove.newSquare.y) ~/ 2);
        ShoveSquare midSquare = getSquareByXY(midX, midY)!;

        if (midSquare.piece == null) {
          // Can only move one square when not jumping
          if ((shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x).abs() >
                  1 ||
              (shoveGameMove.oldSquare.y - shoveGameMove.newSquare.y).abs() >
                  1) {
            return false;
          }
        } else {
          if ((shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x).abs() >
                  2 ||
              (shoveGameMove.oldSquare.y - shoveGameMove.newSquare.y).abs() >
                  2) {
            return false;
          }
        }

      case PieceType.thrower:
        if ((shoveGameMove.oldSquare.x - shoveGameMove.newSquare.x).abs() > 1 ||
            (shoveGameMove.oldSquare.y - shoveGameMove.newSquare.y).abs() > 1) {
          return false;
        }

        if (getSquareByXY(shoveGameMove.newSquare.x, shoveGameMove.newSquare.y)
                ?.piece !=
            null) {
          return false;
        }

      default:
        throw Exception("Piece type not implemented");
    }

    if (getSquareByXY(shoveGameMove.newSquare.x, shoveGameMove.newSquare.y)
            ?.piece
            ?.owner ==
        shoveGameMove.oldSquare.piece?.owner) {
      return false;
    }

    return true;
  }

  void _addPieceToSquare(int x, int y, ShovePiece shovePiece) {
    final piece = shovePiece;
    getSquareByXY(x, y)?.piece = piece;
    pieces.add(piece);
  }

  ShoveSquare? getSquareByXY(int x, int y) {
    return board[(x, y)];
  }

  bool isOutOfBounds(int x, int y) {
    //Edges are a dead zone
    return x < 1 ||
        x >= totalNumberOfRows - 1 ||
        y < 1 ||
        y >= totalNumberOfColumns - 1;
  }

  static Future<ShoveGameMove> isolatedAiMove(ShoveGame shoveGame) async {
    final aiMove =
        await (shoveGame.currentPlayersTurn as IAi).makeMove(shoveGame);
    return aiMove;
  }

  Future<AssetSource?> procceedGameState() async {
    if (currentPlayersTurn is IAi && isGameOver == false) {
      final aiMove = currentPlayersTurn is MinMaxAi
          ? await compute(isolatedAiMove, this)
          : await (currentPlayersTurn as IAi).makeMove(this);

      final audioToPlay = await move(aiMove);
      return audioToPlay;
    }

    return null;
  }

  Future<AssetSource?> move(ShoveGameMove shoveGameMove) async {
    // you cannot move into your own pieces, so we can safely assume that this is always an opponent
    var opponentSquare = shoveGameMove.newSquare;
    AssetSource? audioToPlay;

    if (opponentSquare.piece != null &&
        shoveGameMove.oldSquare.piece?.pieceType == PieceType.shover) {
      var shoveDirection = calculateShoveDirection(
          shoveGameMove.oldSquare, shoveGameMove.newSquare);
      if (shoveDirection == null) {
        final playerName = shoveGameMove.oldSquare.piece?.owner.playerName;
        throw Exception('$playerName made an invalid move!');
      }

      switch (shoveDirection) {
        case ShoveDirection.xPositive:
          audioToPlay = shoveGameMove.shove(shoveGameMove.newSquare.x + 1,
              shoveGameMove.newSquare.y, opponentSquare, this);
        case ShoveDirection.xNegative:
          audioToPlay = shoveGameMove.shove(shoveGameMove.newSquare.x - 1,
              shoveGameMove.newSquare.y, opponentSquare, this);
        case ShoveDirection.yPositive:
          audioToPlay = shoveGameMove.shove(shoveGameMove.newSquare.x,
              shoveGameMove.newSquare.y + 1, opponentSquare, this);
        case ShoveDirection.yNegative:
          audioToPlay = shoveGameMove.shove(shoveGameMove.newSquare.x,
              shoveGameMove.newSquare.y - 1, opponentSquare, this);
      }
    }

    if (shoveGameMove.oldSquare.piece?.pieceType == PieceType.leaper) {
      shoveGameMove.performLeap(this);
    }

    if (shoveGameMove.shoveGameMoveType == ShoveGameMoveType.thrown) {
      audioToPlay = shoveGameMove.throwPiece(this);
    } else {
      shoveGameMove.movePiece(this);
      audioToPlay ??= AssetSource('sounds/Jump_2.mp3');
    }

    shoveGameMove.revertIncapacition(this);

    currentPlayersTurn = currentPlayersTurn.isWhite ? player2 : player1;

    allMadeMoves.add(shoveGameMove);
    checkIfGameIsOver();
    return audioToPlay;
    //printBoard();
  }

  ShoveDirection? calculateShoveDirection(
      ShoveSquare oldSquare, ShoveSquare newSquare) {
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
      ShoveDirection.xPositive => getSquareByXY(x + 1, y)?.piece != null,
      ShoveDirection.xNegative => getSquareByXY(x - 1, y)?.piece != null,
      ShoveDirection.yPositive => getSquareByXY(x, y + 1)?.piece != null,
      ShoveDirection.yNegative => getSquareByXY(x, y - 1)?.piece != null,
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

      var playerMoves =
          allMadeMoves.where((move) => move.madeBy == player).toList();
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

    final player1Repeated = checkIfPlayerHasRepeatedSameMoveThreeTimes(player1);
    final player2Repeated = checkIfPlayerHasRepeatedSameMoveThreeTimes(player2);

    if (player1Repeated && player2Repeated) {
      gameOverState = (winner: null, isOver: true);
      return gameOverState!;
    }
    final player1HasPieceInGoal = player1GoalShoveSquares.any((element) =>
        element.piece?.owner == player1 &&
        element.piece?.pieceType == PieceType.shover);

    final player2HasPieceInGoal = player2GoalShoveSquares.any((element) =>
        element.piece?.owner == player2 &&
        element.piece?.pieceType == PieceType.shover);

    final winningPlayer = player1HasPieceInGoal
        ? player1
        : player2HasPieceInGoal
            ? player2
            : null;

    gameOverState = (winner: winningPlayer, isOver: winningPlayer != null);

    return gameOverState!;
  }

  List<ShoveGameMove> getAllLegalMoves() {
    List<ShoveGameMove> legals = [];

    for (var square in board.values) {
      if (square.piece != null) {
        for (int x = 0; x < totalNumberOfRows; x++) {
          for (int y = 0; y < totalNumberOfColumns; y++) {
            final newSquare = getSquareByXY(x, y);
            if (newSquare == null) continue;

            final neighbors = getAllNeighborSquares(square);

            if (validateMove(
                ShoveGameMove(square, newSquare, currentPlayersTurn))) {
              legals.add(ShoveGameMove(square, newSquare, currentPlayersTurn));
            }

            for (var neighbor in neighbors) {
              if (validateMove(ShoveGameMove(
                  square, newSquare, currentPlayersTurn,
                  throwerSquare: neighbor))) {
                legals.add(ShoveGameMove(square, newSquare, currentPlayersTurn,
                    throwerSquare: neighbor));
              }
            }
          }
        }
      }
    }

    return legals;
  }

  void undoLastMove() {
    if (allMadeMoves.isEmpty) return;

    var lastMove = allMadeMoves.removeLast();

    lastMove.revertMove(this);

    // Switch the current player turn back
    currentPlayersTurn = currentPlayersTurn.isWhite ? player2 : player1;
  }

  ({bool isValid, ShoveSquare? throwerSquare}) shoveSquareIsValidTargetForThrow(
      ShoveSquare square) {
    if (square.piece == null || square.piece?.owner == currentPlayersTurn) {
      return (isValid: false, throwerSquare: null);
    }

    final neighbors = getAllNeighborSquares(square);

    try {
      final ShoveSquare throwerSquare = neighbors.firstWhere((element) {
        final isOpponentsThrower =
            element.piece?.pieceType == PieceType.thrower &&
                element.piece?.owner != currentPlayersTurn;
        final isMyThrowerAndTargetIsOpponentsPiece =
            element.piece?.pieceType == PieceType.thrower &&
                element.piece?.owner == currentPlayersTurn &&
                square.piece?.owner != currentPlayersTurn;

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

  getSquaresDistanceToGoal(IPlayer owner, ShoveSquare square) {
    if (owner == player1) {
      return (player1GoalShoveSquares.first.x - square.x).abs();
    } else {
      return (player2GoalShoveSquares.first.x - square.x).abs();
    }
  }

  int calculateBoardStateHash() {
    var hash = 7;

    for (var piece in pieces) {
      hash = 31 * hash + piece.hashCode;
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
