import 'package:shove/game_objects/shove_square.dart';

class ShoveGameMove {
  final ShoveSquare oldSquare;
  final ShoveSquare newSquare;

  ShoveGameMove(this.oldSquare, this.newSquare);
}
