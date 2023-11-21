import 'dart:io';
import 'dart:math';

import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_square.dart';

class RandomAi extends IPlayer implements IAi {
  RandomAi(super.playerName, super.isWhite);

  @override
  Future<(ShoveSquare, ShoveSquare)> makeMove(ShoveGame game) async {
    final random = Random();
    final availableMoves = game.getAllLegalMoves();
    final move = availableMoves[random.nextInt(availableMoves.length)];
    return move;
  }
}
