import 'package:shove/shove_piece.dart';

class ShoveSquare {
  final int x;
  final int y;
  ShovePiece? piece;

  ShoveSquare(this.x, this.y, this.piece);

  @override
  String toString() {
    return 'ShoveSquare{x: $x, y: $y, piece: $piece}';
  }
}
