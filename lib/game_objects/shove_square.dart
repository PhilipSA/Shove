import 'package:shove/game_objects/dto/shove_square_dto.dart';

class ShoveSquare {
  final int x;
  final int y;
  String? pieceId;

  ShoveSquare(this.x, this.y, this.pieceId);

  factory ShoveSquare.fromDto(ShoveSquareDto dto) {
    return ShoveSquare(dto.x, dto.y, dto.pieceId);
  }

  @override
  String toString() {
    return 'ShoveSquare{x: $x, y: $y, piece: $pieceId}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoveSquare &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          pieceId == other.pieceId;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ pieceId.hashCode;
}
