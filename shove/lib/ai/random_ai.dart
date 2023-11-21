import 'dart:math';

import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/shove_game.dart';

class RandomAi extends IPlayer implements IAi {
  RandomAi(super.playerName, super.isWhite);

  @override
  void makeMove(ShoveGame game) {
    final random = Random();
    final availableMoves = game.getAllLegalMoves();
    final move = availableMoves[random.nextInt(availableMoves.length)];
    game.move(move.$1, move.$2);
  }
}
