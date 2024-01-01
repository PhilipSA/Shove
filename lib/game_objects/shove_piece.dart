import 'dart:convert';
import 'dart:math';

import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_piece_dto.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/resources/shove_assets.dart';

class ShovePiece {
  final String id;
  final PieceType pieceType;
  final TextureAssets? texture;
  bool isIncapacitated = false;
  final IPlayer owner;

  ShovePiece(this.id, this.pieceType, this.texture, this.owner);

  factory ShovePiece.leaper(IPlayer owner) {
    return ShovePiece(getRandString(), PieceType.leaper,
        owner.isWhite ? TextureAssets.leaper : TextureAssets.invLeaper, owner);
  }

  factory ShovePiece.shover(IPlayer owner) {
    return ShovePiece(getRandString(), PieceType.shover,
        owner.isWhite ? TextureAssets.shover : TextureAssets.invShover, owner);
  }

  factory ShovePiece.blocker(IPlayer owner) {
    return ShovePiece(
        getRandString(),
        PieceType.blocker,
        owner.isWhite ? TextureAssets.blocker : TextureAssets.invBlocker,
        owner);
  }

  factory ShovePiece.thrower(IPlayer owner) {
    return ShovePiece(
        getRandString(),
        PieceType.thrower,
        owner.isWhite ? TextureAssets.thrower : TextureAssets.invThrower,
        owner);
  }

  factory ShovePiece.fromDto(ShovePieceDto dto) {
    return ShovePiece(dto.id, dto.pieceType, null, IPlayer.fromDto(dto.owner))
      ..isIncapacitated = dto.isIncapacitated;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ShovePiece &&
        other.pieceType == pieceType &&
        other.owner == owner;
  }

  @override
  int get hashCode => pieceType.hashCode ^ owner.hashCode;
}

String getRandString({int len = 16}) {
  var random = Random.secure();
  var values = List<int>.generate(len, (i) => random.nextInt(255));
  return base64UrlEncode(values);
}
