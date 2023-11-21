import 'dart:math';

import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/shove_game.dart';

class RandomAi implements IAi {
  RandomAi();

  @override
  void makeMove(ShoveGame game) {
    // final random = Random();
    // final availableMoves = game.availableMoves;
    // final move = availableMoves[random.nextInt(availableMoves.length)];
    // game.makeMove(move);
  }
}
