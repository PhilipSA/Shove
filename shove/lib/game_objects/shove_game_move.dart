import 'package:audioplayers/audioplayers.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_square.dart';

class ShoveGameMove {
  final ShoveSquare oldSquare;
  final ShoveSquare newSquare;
  final ShoveGameMoveType shoveGameMoveType;
  final IPlayer madeBy;
  final ShoveSquare? throwerSquare;

  ShovePiece? shovedPiece;
  ShoveSquare? shovedToSquare;
  ShoveSquare? leapedOverSquare;
  ShovePiece? thrownPiece;

  ShoveGameMove(this.oldSquare, this.newSquare, this.madeBy,
      {this.throwerSquare})
      : shoveGameMoveType = throwerSquare != null
            ? ShoveGameMoveType.thrown
            : ShoveGameMoveType.move;

  void revertMove(ShoveGame shoveGame) {
    _revertMovePiece(shoveGame);

    if (shovedPiece != null) {
      _revertShove(shoveGame);
    }

    if (leapedOverSquare != null) {
      _revertLeap(shoveGame);
    }

    if (thrownPiece != null) {
      _revertThrow(shoveGame);
    }
  }

  AssetSource _pieceOutOfBounds(ShoveGame shoveGame, ShovePiece piece) {
    shoveGame.pieces.remove(piece);
    return AssetSource('sounds/YodaScream.mp3');
  }

  void _revertPieceOutOfBounds(ShoveGame shoveGame, ShovePiece piece) {
    final wasYeeted = !shoveGame.pieces.contains(piece);

    if (wasYeeted) {
      shoveGame.pieces.add(piece);
    }
  }

  AssetSource shove(
      int x, int y, ShoveSquare shovedSquare, ShoveGame shoveGame) {
    final AssetSource audioToPlay;

    if (shoveGame.isOutOfBounds(x, y)) {
      audioToPlay = _pieceOutOfBounds(shoveGame, shovedSquare.piece!);
    } else {
      shovedSquare.piece?.isIncapacitated = true;
      final squareToShoveTo = shoveGame.getSquareByXY(x, y);
      squareToShoveTo?.piece = shovedSquare.piece;
      shovedToSquare = squareToShoveTo;
      audioToPlay = AssetSource('sounds/Bonk_1.mp3');
    }

    shovedPiece = shovedSquare.piece;
    shovedSquare.piece = null;
    return audioToPlay;
  }

  void _revertShove(ShoveGame shoveGame) {
    _revertPieceOutOfBounds(shoveGame, shovedPiece!);
    shovedPiece?.isIncapacitated = false;
    shovedToSquare?.piece = null;
    shoveGame.getSquareByXY(newSquare.x, newSquare.y)!.piece = shovedPiece;
  }

  void performLeap(ShoveGame shoveGame) {
    int midX = (oldSquare.x + newSquare.x) ~/ 2;
    int midY = ((oldSquare.y + newSquare.y) ~/ 2);
    ShoveSquare squareToIncapacitate = shoveGame.getSquareByXY(midX, midY)!;

    squareToIncapacitate.piece?.isIncapacitated = true;

    leapedOverSquare = squareToIncapacitate;
  }

  void _revertLeap(ShoveGame shoveGame) {
    leapedOverSquare?.piece?.isIncapacitated = false;
  }

  AssetSource throwPiece(ShoveGame shoveGame) {
    thrownPiece = oldSquare.piece;

    if (shoveGame.isOutOfBounds(newSquare.x, newSquare.y)) {
      final audioToPlay = _pieceOutOfBounds(shoveGame, oldSquare.piece!);
      shoveGame.getSquareByXY(oldSquare.x, oldSquare.y)!.piece = null;
      return audioToPlay;
    } else {
      oldSquare.piece!.isIncapacitated = true;
      shoveGame.getSquareByXY(newSquare.x, newSquare.y)!.piece =
          oldSquare.piece;
      shoveGame.getSquareByXY(oldSquare.x, oldSquare.y)!.piece = null;
      return AssetSource('sounds/ThrowSound.mp3');
    }
  }

  void _revertThrow(ShoveGame shoveGame) {
    _revertPieceOutOfBounds(shoveGame, thrownPiece!);
    thrownPiece!.isIncapacitated = false;
    oldSquare.piece = thrownPiece;
    newSquare.piece = null;
  }

  void movePiece(ShoveGame shoveGame) {
    shoveGame.getSquareByXY(newSquare.x, newSquare.y)!.piece = oldSquare.piece;
    shoveGame.getSquareByXY(oldSquare.x, oldSquare.y)!.piece = null;
  }

  void _revertMovePiece(ShoveGame shoveGame) {
    shoveGame.getSquareByXY(oldSquare.x, oldSquare.y)!.piece = newSquare.piece;
    shoveGame.getSquareByXY(newSquare.x, newSquare.y)!.piece = null;
  }

  void revertIncapacition(ShoveGame shoveGame) {
    for (var piece in shoveGame.pieces.where((element) =>
        element.owner == shoveGame.currentPlayersTurn &&
        element.isIncapacitated)) {
      piece.isIncapacitated = false;
    }
  }

  @override
  String toString() {
    return 'ShoveGameMove{oldSquare: $oldSquare, newSquare: $newSquare, shoveGameMoveType: $shoveGameMoveType}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoveGameMove &&
          runtimeType == other.runtimeType &&
          oldSquare == other.oldSquare &&
          newSquare == other.newSquare &&
          madeBy.playerName == other.madeBy.playerName &&
          shoveGameMoveType == other.shoveGameMoveType;

  @override
  int get hashCode =>
      oldSquare.hashCode ^
      newSquare.hashCode ^
      madeBy.playerName.hashCode ^
      shoveGameMoveType.hashCode;
}
