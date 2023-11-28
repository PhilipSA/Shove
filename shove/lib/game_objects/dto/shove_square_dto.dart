import 'package:json_annotation/json_annotation.dart';
import 'package:shove/game_objects/dto/shove_piece_dto.dart';
import 'package:shove/game_objects/shove_square.dart';

part 'shove_square_dto.g.dart';

@JsonSerializable()
class ShoveSquareDto {
  final int x;
  final int y;
  final ShovePieceDto? piece;

  ShoveSquareDto(this.x, this.y, this.piece);

  factory ShoveSquareDto.fromSquare(ShoveSquare square) {
    return ShoveSquareDto(square.x, square.y,
        square.piece != null ? ShovePieceDto.fromPiece(square.piece!) : null);
  }

  factory ShoveSquareDto.fromJson(Map<String, dynamic> json) =>
      _$ShoveSquareDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ShoveSquareDtoToJson(this);
}
