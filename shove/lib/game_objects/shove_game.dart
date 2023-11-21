import 'package:flutter/widgets.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_direction.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/game_objects/shove_square.dart';

class ShoveGame {
  final List<ShovePiece> pieces;

  static const int totalNumberOfRows = 8;
  static const int totalNumberOfColumns = 8;

  final ShovePlayer player1;
  final ShovePlayer player2;

  ShovePlayer currentPlayersTurn;

  ShoveGame(this.player1, this.player2)
      : currentPlayersTurn = player1,
        pieces = getInitialPieces(player1, player2) {
    for (int currentCol = 0; currentCol < totalNumberOfColumns; currentCol++) {
      getSquareByXY(0, currentCol).piece = pieces
          .where((element) => element.owner == player2)
          .toList()[currentCol];
      getSquareByXY(7, currentCol).piece = pieces
          .where((element) => element.owner == player1)
          .toList()[currentCol];
    }
  }

  static List<ShovePiece> getInitialPieces(
      ShovePlayer player1, ShovePlayer player2) {
    final player1Pieces = List.generate(
        8,
        (index) => ShovePiece(PieceType.shover,
            Image.asset('assets/textures/shover.png'), player1));

    final player2Pieces = List.generate(
        8,
        (index) => ShovePiece(PieceType.shover,
            Image.asset('assets/textures/shover.png'), player2));

    return player1Pieces..addAll(player2Pieces);
  }

  final _board = List<List<ShoveSquare>>.generate(
      totalNumberOfRows,
      (i) => List<ShoveSquare>.generate(
          totalNumberOfColumns, (index) => ShoveSquare(i, index % 8, null),
          growable: false),
      growable: false);

  bool validateMove(ShoveSquare oldSquare, ShoveSquare newSquare) {
    if (oldSquare.piece == null) {
      return false;
    }

    if (newSquare.x > 7 ||
        newSquare.x < 0 ||
        newSquare.y > 7 ||
        newSquare.y < 0) {
      return false;
    }

    if (oldSquare.piece!.pieceType == PieceType.shover) {
      if ((oldSquare.x - newSquare.x).abs() > 1) {
        return false;
      }

      if ((oldSquare.y - newSquare.y).abs() > 1) {
        return false;
      }

      // Shovers cannot move horizontally
      if ((oldSquare.x - newSquare.x).abs() > 0 &&
          (oldSquare.y - newSquare.y).abs() > 0) {
        return false;
      }
    }

    if (getSquareByXY(newSquare.x, newSquare.y).piece?.owner == oldSquare.piece?.owner) {
      return false;
    }

    return true;
  }

  ShoveSquare getSquareByXY(int x, int y) {
    return _board[x][y];
  }

  void move(ShoveSquare oldSquare, ShoveSquare newSquare) {
    var shoveDirection = calculateShoveDirection(oldSquare, newSquare);
    if (shoveDirection == null) {
      return;
    }

    var opponentPiece = getSquareByXY(newSquare.x, newSquare.y).piece;

    if (opponentPiece != null) {
      // todo: check if other pieces are in the reach of the shove
      switch (shoveDirection) {
        case ShoveDirection.xPositive:
          getSquareByXY(newSquare.x + 1, newSquare.y).piece = opponentPiece;
        case ShoveDirection.xNegative:
          getSquareByXY(newSquare.x - 1, newSquare.y).piece = opponentPiece;
        case ShoveDirection.yPositive:
          getSquareByXY(newSquare.x, newSquare.y + 1).piece = opponentPiece;
        case ShoveDirection.yNegative:
          getSquareByXY(newSquare.x, newSquare.y - 1).piece = opponentPiece;
      }

      opponentPiece = null;
    }

    getSquareByXY(newSquare.x, newSquare.y).piece = oldSquare.piece;
    getSquareByXY(oldSquare.x, oldSquare.y).piece = null;

    currentPlayersTurn = currentPlayersTurn.isWhite ? player2 : player1;

    printBoard();
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

  void printBoard() {
    for (var row in _board) {
      String rowDisplay = '';
      for (var square in row) {
        String pieceDisplay = square.piece != null ? "P" : ".";
        rowDisplay += '$pieceDisplay\t'; // Building the row string
      }
      print(rowDisplay); // Printing the entire row
    }
  }
}
