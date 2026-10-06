import 'dart:collection';

import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/game_objects/shove_square.dart';

/// A position where the player at the bottom of the board, who moves first,
/// has to force a win in [movesToWin] moves.
///
/// [layout] has one string per board row, top row first. Upper case letters are
/// the player's pieces, lower case letters the opponent's, and '.' is an empty square:
/// S shover, B blocker, L leaper, T thrower, C charger, H hook.
class ShovePuzzle {
  final String title;
  final String hint;
  final int movesToWin;
  final List<String> layout;

  const ShovePuzzle({
    required this.title,
    required this.hint,
    required this.movesToWin,
    required this.layout,
  });

  ShoveGame buildGame() {
    final player = ShovePlayer('You', true);
    final opponent = ShovePlayer('Opponent', false);

    final board = HashMap<(int x, int y), ShoveSquare>();
    final pieces = <String, ShovePiece>{};
    for (var x = 0; x < ShoveGame.totalNumberOfRows; x++) {
      for (var y = 0; y < ShoveGame.totalNumberOfColumns; y++) {
        final symbol = layout[x][y];
        final square = ShoveSquare(x, y, null);
        board[(x, y)] = square;
        if (symbol == '.') continue;

        final owner = symbol == symbol.toUpperCase() ? player : opponent;
        final piece = switch (symbol.toUpperCase()) {
          'S' => ShovePiece.shover(owner),
          'B' => ShovePiece.blocker(owner),
          'L' => ShovePiece.leaper(owner),
          'T' => ShovePiece.thrower(owner),
          'C' => ShovePiece.charger(owner),
          'H' => ShovePiece.hook(owner),
          _ => throw ArgumentError(
            'Unknown piece "$symbol" in puzzle "$title"',
          ),
        };
        square.pieceId = piece.id;
        pieces[piece.id] = piece;
      }
    }

    return ShoveGame(
      player,
      opponent,
      customBoard: board,
      customPieces: pieces,
    );
  }
}
