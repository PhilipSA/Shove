import 'package:flutter/material.dart';
import 'package:shove/piece_type.dart';

class ShovePiece {
  final PieceType pieceType;
  final Image texture;

  ShovePiece(this.pieceType, this.texture);
}
