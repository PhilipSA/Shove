import 'package:json_annotation/json_annotation.dart';
import 'package:shove/game_objects/shove_piece.dart';

part 'shove_piece_dto.g.dart';

@JsonSerializable()
class ShovePieceDto {
  final String pieceType;
  final String texture;
  final bool isIncapacitated;
  final String owner;

  ShovePieceDto(this.pieceType, this.texture, this.isIncapacitated, this.owner);

  factory ShovePieceDto.fromPiece(ShovePiece piece) {
    return ShovePieceDto(
        piece.pieceType, piece.texture, piece.isIncapacitated, piece.owner);
  }

  factory ShovePieceDto.fromJson(Map<String, dynamic> json) =>
      _$ShovePieceDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ShovePieceDtoToJson(this);
}
