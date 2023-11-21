import 'package:flutter/material.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/piece_type.dart';

class ShovePiece {
  final PieceType pieceType;
  final Image texture;
  bool isIncapacitated = false;
  final IPlayer owner;

  ShovePiece(this.pieceType, this.texture, this.owner);
}
