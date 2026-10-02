import 'package:mockito/annotations.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_piece.dart';

import 'test_helpers.mocks.dart';

export 'test_helpers.mocks.dart';

@GenerateNiceMocks([MockSpec<ShoveAudioPlayer>()])
/// Hands out audio player mocks and remembers them for verification.
class MockAudioPlayers {
  final created = <MockShoveAudioPlayer>[];

  ShoveAudioPlayer create({String? playerId}) {
    final player = MockShoveAudioPlayer();
    created.add(player);
    return player;
  }
}

/// A game between [player1] and [player2] with no pieces on the board.
ShoveGame emptyGame(IPlayer player1, IPlayer player2) {
  final game = ShoveGame(player1, player2);
  for (final square in game.board.values) {
    square.pieceId = null;
  }
  game.pieces.clear();
  return game;
}

ShovePiece place(ShoveGame game, int x, int y, ShovePiece piece) {
  game.getSquareByXY(x, y)!.pieceId = piece.id;
  game.pieces[piece.id] = piece;
  return piece;
}

ShoveGameMove moveOf(
  ShoveGame game,
  (int, int) from,
  (int, int) to, {
  (int, int)? thrower,
}) => ShoveGameMove(
  game.getSquareByXY(from.$1, from.$2)!,
  game.getSquareByXY(to.$1, to.$2)!,
  game.currentPlayersTurn,
  throwerSquare: thrower == null
      ? null
      : game.getSquareByXY(thrower.$1, thrower.$2),
);

/// Plays the blockers back and forth until one move short of a repetition draw.
void playUntilOneMoveBeforeRepetition(ShoveGame game) {
  for (var i = 0; i < 9; i++) {
    final white = i % 4 == 0 ? ((5, 3), (5, 4)) : ((5, 4), (5, 3));
    final black = i % 4 == 1 ? ((2, 3), (2, 4)) : ((2, 4), (2, 3));
    final (from, to) = i.isEven ? white : black;
    game.move(moveOf(game, from, to));
  }
}

/// Position for [playUntilOneMoveBeforeRepetition]: one shover and blocker each.
ShoveGame repetitionGame(IPlayer white, IPlayer black) {
  final game = emptyGame(white, black);
  place(game, 6, 0, ShovePiece.shover(white));
  place(game, 5, 3, ShovePiece.blocker(white));
  place(game, 1, 7, ShovePiece.shover(black));
  place(game, 2, 3, ShovePiece.blocker(black));
  return game;
}
