import 'package:flutter_svg/flutter_svg.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/piece_type.dart';

class ShovePiece {
  final PieceType pieceType;
  final SvgPicture texture;
  bool isIncapacitated = false;
  final IPlayer owner;

  ShovePiece(this.pieceType, this.texture, this.owner);
}
