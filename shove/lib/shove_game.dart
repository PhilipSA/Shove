import 'package:flutter/widgets.dart';
import 'package:shove/piece_type.dart';
import 'package:shove/shove_piece.dart';
import 'package:shove/shove_square.dart';

class ShoveGame {
  final List<ShovePiece> pieces;

  static const int row = 8;
  static const int col = 8;

  var board = List<List>.generate(
      row,
      (i) => List<ShoveSquare>.generate(col, (index) => ShoveSquare(col, row),
          growable: false),
      growable: false);

  ShoveGame() : pieces = List.generate(
      5,
      (index) => ShovePiece(
          PieceType.shover, Image.asset('assets/textures/shover.png'))) {
    board[0][0].piece = pieces.first;
  }
  
}