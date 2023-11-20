import 'package:flutter/widgets.dart';
import 'package:shove/piece_type.dart';
import 'package:shove/shove_piece.dart';
import 'package:shove/shove_square.dart';

class ShoveGame {
  final List<ShovePiece> pieces;

  static const int row = 7;
  static const int col = 7;

  var twoDList = List<List>.generate(
      row,
      (i) => List<dynamic>.generate(col, (index) => ShoveSquare(col, row),
          growable: false),
      growable: false);

  ShoveGame()
      : pieces = List.generate(
            5,
            (index) => ShovePiece(
                PieceType.shover, Image.asset('textures/shover.png')));
}
