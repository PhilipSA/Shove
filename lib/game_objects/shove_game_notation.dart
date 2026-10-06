import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';

/// One move of a pasted game, as board coordinates (row `x`, column `y`).
class ShoveMoveSpec {
  final (int, int) from;
  final (int, int) to;
  final (int, int)? thrower;
  final String text;

  const ShoveMoveSpec(this.from, this.to, this.thrower, this.text);
}

/// Text form of a whole game, like chess PGN:
///
///     [White "Alice"]
///     [Black "Bob"]
///
///     1. a2-a3 h7-h6
///     2. b1-c3 g8-f6
///
/// A move is `from-to`; throws and hook pulls add the square of the piece doing it
/// (`d1-e2@e1`). Move numbers, tags, comments and the `×`, `→`, `~` separators of the
/// move list are accepted when reading.
class ShoveGameNotation {
  final String? white;
  final String? black;
  final List<ShoveMoveSpec> moves;

  const ShoveGameNotation({this.white, this.black, required this.moves});

  static final _tag = RegExp(r'\[\s*(\w+)\s+"([^"]*)"\s*\]');
  static final _anyTag = RegExp(r'\[[^\]]*\]');
  static final _move = RegExp(
    r'^([a-h][1-8])[-–×x→~>]([a-h][1-8])(?:@([a-h][1-8]))?$',
  );
  static const _results = {'1-0', '0-1', '1/2-1/2', '*'};

  static String format(ShoveGame game) {
    final moves = game.allMadeMoves;
    final lines = [
      '[White "${_tagValue(game.player1.playerName)}"]',
      '[Black "${_tagValue(game.player2.playerName)}"]',
      '',
      for (var i = 0; i < moves.length; i += 2)
        '${i ~/ 2 + 1}. ${_moveText(moves[i])}'
            '${i + 1 < moves.length ? ' ${_moveText(moves[i + 1])}' : ''}',
    ];
    return lines.join('\n');
  }

  /// Throws a [FormatException] with a readable message when [text] has no readable moves.
  factory ShoveGameNotation.parse(String text) {
    String? white, black;
    for (final tag in _tag.allMatches(text)) {
      final value = tag.group(2)!.trim();
      if (value.isEmpty) continue;
      switch (tag.group(1)!.toLowerCase()) {
        case 'white':
          white = value;
        case 'black':
          black = value;
      }
    }

    final body = text
        .replaceAll(_anyTag, ' ')
        .replaceAll(RegExp(r'\{[^}]*\}'), ' ')
        .replaceAll(RegExp(r';[^\n]*'), ' ')
        .replaceAll('✕', ' ');

    final moves = <ShoveMoveSpec>[];
    for (final raw in body.split(RegExp(r'\s+'))) {
      final token = raw.toLowerCase().replaceFirst(RegExp(r'^\d+\.+'), '');
      if (token.isEmpty || _results.contains(token)) continue;

      final match = _move.firstMatch(token);
      if (match == null) {
        throw FormatException(
          'Could not read "$raw" as move ${moves.length + 1}. Moves look like a2-a3.',
        );
      }
      moves.add(
        ShoveMoveSpec(
          _square(match.group(1)!),
          _square(match.group(2)!),
          match.group(3) == null ? null : _square(match.group(3)!),
          token,
        ),
      );
    }

    if (moves.isEmpty) {
      throw const FormatException('No moves found.');
    }
    return ShoveGameNotation(white: white, black: black, moves: moves);
  }

  /// Plays the moves on [game] (which must be at its start position).
  /// Throws a [FormatException] naming the first move that cannot be played.
  void replayOn(ShoveGame game, {void Function()? afterMove}) {
    for (var i = 0; i < moves.length; i++) {
      game.move(_resolve(game, moves[i], i + 1));
      afterMove?.call();
    }
  }

  static ShoveGameMove _resolve(ShoveGame game, ShoveMoveSpec spec, int ply) {
    if (game.isGameOver) {
      throw FormatException('The game was already over before move $ply.');
    }

    final from = game.getSquareByXY(spec.from.$1, spec.from.$2)!;
    final candidates = [
      for (final move in game.getLegalMovesFrom(from))
        if (move.newSquare.x == spec.to.$1 && move.newSquare.y == spec.to.$2)
          move,
    ];

    final thrower = spec.thrower;
    if (thrower != null) {
      for (final move in candidates) {
        if (move.throwerSquare?.x == thrower.$1 &&
            move.throwerSquare?.y == thrower.$2) {
          return move;
        }
      }
    } else {
      // A piece moving by itself wins over being thrown or pulled to the same square
      for (final move in candidates) {
        if (move.throwerSquare == null) return move;
      }
      if (candidates.length == 1) return candidates.first;
      if (candidates.length > 1) {
        throw FormatException(
          'Move $ply (${spec.text}) can be done by several pieces; add @ and the square of the one that does it.',
        );
      }
    }

    throw FormatException(
      'Move $ply (${spec.text}) is not legal for ${game.currentPlayersTurn.playerName}.',
    );
  }

  static (int, int) _square(String name) => (
    ShoveGame.totalNumberOfRows - int.parse(name[1]),
    name.codeUnitAt(0) - 97,
  );

  static String _squareName(int x, int y) =>
      '${String.fromCharCode(97 + y)}${ShoveGame.totalNumberOfRows - x}';

  static String _moveText(ShoveGameMove move) {
    final thrower = move.throwerSquare;
    return '${_squareName(move.oldSquare.x, move.oldSquare.y)}-'
        '${_squareName(move.newSquare.x, move.newSquare.y)}'
        '${thrower == null ? '' : '@${_squareName(thrower.x, thrower.y)}'}';
  }

  static String _tagValue(String name) =>
      name.replaceAll(RegExp(r'["\]\[\r\n]'), ' ').trim();
}
