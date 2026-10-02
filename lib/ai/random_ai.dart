import 'dart:math';

import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';

class RandomAi extends IPlayer implements IAi {
  final Random _random;

  RandomAi(super.playerName, super.isWhite, {Random? random})
    : _random = random ?? Random();

  @override
  Future<ShoveGameMove> makeMove(ShoveGame game) async {
    final availableMoves = game.getAllLegalMoves();
    return availableMoves[_random.nextInt(availableMoves.length)];
  }
}
