import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_square.dart';
import 'package:shove/resources/shove_assets.dart';

/// A played move, described right after it was made (squares on the live board change later).
class ShoveMoveRecord {
  final ShoveGameMove move;
  final TextureAssets? texture;
  final String notation;
  final String description;

  const ShoveMoveRecord({
    required this.move,
    required this.texture,
    required this.notation,
    required this.description,
  });

  /// Must be called right after [move] was made on [game].
  factory ShoveMoveRecord.of(ShoveGame game, ShoveGameMove move) {
    final mover = move.throwerSquare != null
        ? game.pieces[move.throwerSquare!.pieceId]
        : game.pieces[move.newSquare.pieceId];
    return ShoveMoveRecord(
      move: move,
      texture: mover?.texture,
      notation: _notation(move),
      description: describeMove(game, move),
    );
  }
}

String squareName(ShoveSquare square) =>
    '${String.fromCharCode(97 + square.y)}${ShoveGame.totalNumberOfRows - square.x}';

String _notation(ShoveGameMove move) {
  final from = squareName(move.oldSquare);
  final to = squareName(move.newSquare);
  if (move.eliminatedPiece) return '$from×$to ✕';
  if (move.shovedPiece != null) return '$from×$to';
  if (move.thrownPiece != null) return '$from→$to';
  if (move.leapedOverSquare != null) return '$from~$to';
  return '$from–$to';
}

/// Sentence describing [move]; call it right after the move was made on [game].
String describeMove(ShoveGame game, ShoveGameMove move) {
  final name = move.madeBy.playerName;
  final recoil =
      game.pieces[move.newSquare.pieceId]?.pieceType == PieceType.charger
      ? ' The charger is stunned too.'
      : '';

  if (move.eliminatedPiece) {
    return '$name shoved a ${move.shovedPiece!.pieceType.name} off the board!$recoil';
  }
  if (move.shovedPiece != null) {
    return '$name shoved a ${move.shovedPiece!.pieceType.name} – it is stunned.$recoil';
  }
  if (move.thrownPiece != null) {
    final thrown = move.thrownPiece!;
    final byHook =
        game.pieces[move.throwerSquare!.pieceId]?.pieceType == PieceType.hook;
    if (!byHook) {
      return '$name threw a ${thrown.pieceType.name} – it is stunned.';
    }
    return thrown.owner == move.madeBy
        ? '$name pulled a ${thrown.pieceType.name} closer.'
        : '$name pulled a ${thrown.pieceType.name} – it is stunned.';
  }
  if (move.leapedOverSquare != null) {
    final victim = game.pieces[move.leapedOverSquare!.pieceId];
    return '$name leaped over a ${victim?.pieceType.name ?? 'piece'} – it is stunned.';
  }
  final moved = game.pieces[move.newSquare.pieceId];
  return '$name moved a ${moved?.pieceType.name ?? 'piece'}.';
}
