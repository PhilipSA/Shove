import 'package:json_annotation/json_annotation.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_player_dto.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_piece.dart';

part 'shove_piece_dto.g.dart';

@JsonSerializable()
class ShovePieceDto {
  final PieceType pieceType;
  final String texture;
  final bool isIncapacitated;
  final ShovePlayerDto owner;

  ShovePieceDto(this.pieceType, this.texture, this.isIncapacitated, this.owner);

  factory ShovePieceDto.fromPiece(ShovePiece piece) {
    return ShovePieceDto(piece.pieceType, piece.texture.toString(),
        piece.isIncapacitated, ShovePlayerDto.fromPlayer(piece.owner));
  }

  factory ShovePieceDto.fromJson(Map<String, dynamic> json) =>
      _$ShovePieceDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ShovePieceDtoToJson(this);
}
