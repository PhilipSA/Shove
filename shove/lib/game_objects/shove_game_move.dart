import 'package:audioplayers/audioplayers.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_square.dart';

class ShoveGameMove {
  final ShoveSquare oldSquare;
  final ShoveSquare newSquare;
  final ShoveGameMoveType shoveGameMoveType;
  final ShoveSquare? throwerSquare;

  ShovePiece? _shovedPiece;
  ShoveSquare? _shovedToSquare;
  ShoveSquare? _leapedOverSquare;
  ShovePiece? _thrownPiece;

  ShoveGameMove(this.oldSquare, this.newSquare, {this.throwerSquare})
      : shoveGameMoveType = throwerSquare != null
            ? ShoveGameMoveType.thrown
            : ShoveGameMoveType.move;

  void revertMove(ShoveGame shoveGame) {
    _revertMovePiece(shoveGame);

    if (_shovedPiece != null) {
      _revertShove(shoveGame);
    }

    if (_leapedOverSquare != null) {
      _revertLeap(shoveGame);
    }

    if (_thrownPiece != null) {
      _revertThrow(shoveGame);
    }
  }

  void _pieceOutOfBounds(ShoveGame shoveGame, ShovePiece piece) {
    shoveGame.pieces.remove(piece);
    AudioPlayer().play(AssetSource('sounds/Yodascream.mp3'));
  }

  void _revertPieceOutOfBounds(ShoveGame shoveGame, ShovePiece piece) {
    final wasYeeted = !shoveGame.pieces.contains(piece);

    if (wasYeeted) {
      shoveGame.pieces.add(_shovedPiece!);
    }
  }

  void shove(int x, int y, ShoveSquare shovedSquare, ShoveGame shoveGame) {
    if (shoveGame.isOutOfBounds(x, y)) {
      _pieceOutOfBounds(shoveGame, shovedSquare.piece!);
    } else {
      shovedSquare.piece?.isIncapacitated = true;
      final squareToShoveTo = shoveGame.getSquareByXY(x, y);
      squareToShoveTo?.piece = shovedSquare.piece;
      _shovedToSquare = squareToShoveTo;
      AudioPlayer().play(AssetSource('sounds/Bonk_1.mp3'));
    }

    _shovedPiece = shovedSquare.piece;
    shovedSquare.piece = null;
  }

  void _revertShove(ShoveGame shoveGame) {
    _revertPieceOutOfBounds(shoveGame, _shovedPiece!);
    _shovedPiece?.isIncapacitated = false;
    _shovedToSquare?.piece = null;
    shoveGame.getSquareByXY(newSquare.x, newSquare.y)!.piece = _shovedPiece;
  }

  void performLeap(ShoveGame shoveGame) {
    int midX = (oldSquare.x + newSquare.x) ~/ 2;
    int midY = ((oldSquare.y + newSquare.y) ~/ 2);
    ShoveSquare squareToIncapacitate = shoveGame.getSquareByXY(midX, midY)!;

    squareToIncapacitate.piece?.isIncapacitated = true;

    _leapedOverSquare = squareToIncapacitate;
  }

  void _revertLeap(ShoveGame shoveGame) {
    _leapedOverSquare?.piece?.isIncapacitated = false;
  }

  void throwPiece(ShoveGame shoveGame) {
    _thrownPiece = oldSquare.piece;

    if (shoveGame.isOutOfBounds(newSquare.x, newSquare.y)) {
      _pieceOutOfBounds(shoveGame, oldSquare.piece!);
      shoveGame.getSquareByXY(oldSquare.x, oldSquare.y)!.piece = null;
    } else {
      oldSquare.piece!.isIncapacitated = true;
      shoveGame.getSquareByXY(newSquare.x, newSquare.y)!.piece =
          oldSquare.piece;
      shoveGame.getSquareByXY(oldSquare.x, oldSquare.y)!.piece = null;
      AudioPlayer().play(AssetSource('sounds/ThrowSound.mp3'));
    }
  }

  void _revertThrow(ShoveGame shoveGame) {
    _revertPieceOutOfBounds(shoveGame, _thrownPiece!);
    _thrownPiece!.isIncapacitated = false;
    oldSquare.piece = _thrownPiece;
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
    for (var piece in shoveGame.pieces
        .where((element) => element.owner == shoveGame.currentPlayersTurn)) {
      piece.isIncapacitated = false;
    }
  }

  @override
  String toString() {
    return 'ShoveGameMove{oldSquare: $oldSquare, newSquare: $newSquare, shoveGameMoveType: $shoveGameMoveType}';
  }
}
