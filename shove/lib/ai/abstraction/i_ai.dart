import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_square.dart';

abstract class IAi {
  Future<(ShoveSquare, ShoveSquare)> makeMove(ShoveGame game);
}
