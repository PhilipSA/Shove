import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/resources/shove_assets.dart';

class ShovePiece {
  final PieceType pieceType;
  final TextureAssets? texture;
  bool isIncapacitated = false;
  final IPlayer owner;

  ShovePiece(this.pieceType, this.texture, this.owner);

  factory ShovePiece.leaper(IPlayer owner) {
    return ShovePiece(PieceType.leaper,
        owner.isWhite ? TextureAssets.leaper : TextureAssets.invLeaper, owner);
  }

  factory ShovePiece.shover(IPlayer owner) {
    return ShovePiece(PieceType.shover,
        owner.isWhite ? TextureAssets.shover : TextureAssets.invShover, owner);
  }

  factory ShovePiece.blocker(IPlayer owner) {
    return ShovePiece(
        PieceType.blocker,
        owner.isWhite ? TextureAssets.blocker : TextureAssets.invBlocker,
        owner);
  }

  factory ShovePiece.thrower(IPlayer owner) {
    return ShovePiece(
        PieceType.thrower,
        owner.isWhite ? TextureAssets.thrower : TextureAssets.invThrower,
        owner);
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
