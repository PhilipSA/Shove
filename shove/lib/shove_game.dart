import 'package:flutter/widgets.dart';
import 'package:shove/piece_type.dart';
import 'package:shove/shove_piece.dart';
import 'package:shove/shove_square.dart';

class ShoveGame {
  final List<ShovePiece> pieces;

  static const int totalNumberOfRows = 8;
  static const int totalNumberOfColumns = 8;

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

    // todo: validate piece-specific logic here
    if (oldSquare.piece!.pieceType != PieceType.shover) {
      return false;
    }

    if ((oldSquare.x - newSquare.x).abs() > 1 ||
        (oldSquare.y - newSquare.y).abs() > 1) {
      return false;
    }

    if (getSquareByXY(newSquare.x, newSquare.y).piece != null) {
      return false;
    }

    return true;
  }

  ShoveSquare getSquareByXY(int x, int y) {
    return _board[x][y];
  }

  void move(ShoveSquare oldSquare, ShoveSquare newSquare) {
    getSquareByXY(newSquare.x, newSquare.y).piece = oldSquare.piece;
    getSquareByXY(oldSquare.x, oldSquare.y).piece = null;

    printBoard();
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

  ShoveGame()
      : pieces = List.generate(
            16,
            (index) => ShovePiece(
                PieceType.shover, Image.asset('assets/textures/shover.png'))) {
    for (int currentCol = 0; currentCol < totalNumberOfColumns; currentCol++) {
      getSquareByXY(0, currentCol).piece = pieces[currentCol];
      getSquareByXY(7, currentCol).piece = pieces[8 + currentCol];
    }
  }
}
