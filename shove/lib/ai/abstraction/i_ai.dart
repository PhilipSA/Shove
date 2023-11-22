import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';

abstract class IAi {
  Future<ShoveGameMove> makeMove(ShoveGame game);
}
