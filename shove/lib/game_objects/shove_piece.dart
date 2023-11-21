import 'package:flutter/material.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_player.dart';

class ShovePiece {
  final PieceType pieceType;
  final Image texture;
  final ShovePlayer owner;

  ShovePiece(this.pieceType, this.texture, this.owner);
}
