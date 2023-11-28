import 'package:flutter_svg/flutter_svg.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_piece_dto.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_player.dart';

class ShovePiece {
  final PieceType pieceType;
  final SvgPicture texture;
  bool isIncapacitated = false;
  final IPlayer owner;

  ShovePiece(this.pieceType, this.texture, this.owner);

  factory ShovePiece.fromDto(ShovePieceDto dto) {
    return ShovePiece(dto.pieceType, SvgPicture.asset(dto.texture),
        ShovePlayer.fromDto(dto.owner));
  }

  factory ShovePiece.leaper(IPlayer owner) {
    return ShovePiece(
        PieceType.leaper,
        SvgPicture.asset(owner.isWhite
            ? 'assets/textures/hoppare.svg'
            : 'assets/textures/inv_hoppare.svg'),
        owner);
  }

  factory ShovePiece.shover(IPlayer owner) {
    return ShovePiece(
        PieceType.shover,
        SvgPicture.asset(owner.isWhite
            ? 'assets/textures/knuffare.svg'
            : 'assets/textures/inv_knuffare.svg'),
        owner);
  }

  factory ShovePiece.blocker(IPlayer owner) {
    return ShovePiece(
        PieceType.blocker,
        SvgPicture.asset(owner.isWhite
            ? 'assets/textures/ankare.svg'
            : 'assets/textures/inv_ankare.svg'),
        owner);
  }

  factory ShovePiece.thrower(IPlayer owner) {
    return ShovePiece(
        PieceType.thrower,
        SvgPicture.asset(owner.isWhite
            ? 'assets/textures/kastare.svg'
            : 'assets/textures/inv_kastare.svg'),
        owner);
  }
}
