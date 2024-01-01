import 'package:json_annotation/json_annotation.dart';
import 'package:shove/game_objects/shove_square.dart';

import 'shove_piece_dto.dart';

part 'shove_square_dto.g.dart';

@JsonSerializable()
class ShoveSquareDto {
  final int x;
  final int y;
  final String? pieceId;

  ShoveSquareDto(this.x, this.y, this.pieceId);

  factory ShoveSquareDto.fromSquare(ShoveSquare square) {
    return ShoveSquareDto(square.x, square.y, square.pieceId);
  }

  factory ShoveSquareDto.fromJson(Map<String, dynamic> json) =>
      _$ShoveSquareDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ShoveSquareDtoToJson(this);
}
