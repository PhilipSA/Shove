import 'package:shove/game_objects/shove_piece.dart';

class ShoveSquare {
  final int x;
  final int y;
  ShovePiece? piece;

  ShoveSquare(this.x, this.y, this.piece);

  @override
  String toString() {
    return 'ShoveSquare{x: $x, y: $y, piece: $piece}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoveSquare &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          piece == other.piece;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ piece.hashCode;
}