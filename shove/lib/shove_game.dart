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
      (i) => List<ShoveSquare>.generate(col, (index) => ShoveSquare(col, row, null),
          growable: false),
      growable: false);

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
