import 'package:flutter/widgets.dart';
import 'package:shove/piece_type.dart';
import 'package:shove/shove_piece.dart';
import 'package:shove/shove_square.dart';

class ShoveGame {
  final List<ShovePiece> pieces;

  static const int row = 8;
  static const int col = 8;

  var board = List<List<ShoveSquare>>.generate(
      row,
      (i) => List<ShoveSquare>.generate(
          col, (index) => ShoveSquare(col, row, null),
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

    if (board[newSquare.y][newSquare.x].piece != null) {
      return false;
    }

    return true;
  }

  ShoveGame()
      : pieces = List.generate(
            16,
            (index) => ShovePiece(
                PieceType.shover, Image.asset('assets/textures/shover.png'))) {
    for (int currentCol = 0; currentCol < col; currentCol++) {
      board[0][currentCol].piece = pieces[currentCol];
      board[7][currentCol].piece = pieces[8 + currentCol];
    }
  }
}
