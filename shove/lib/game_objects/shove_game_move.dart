import 'package:audioplayers/audioplayers.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_square.dart';

class ShoveGameMove {
  final ShoveSquare oldSquare;
  final ShoveSquare newSquare;
  final ShoveGameMoveType shoveGameMoveType;

  var _didShove = false;
  ShovePiece? _didIncapacitatePiece = null;

  ShoveGameMove(this.oldSquare, this.newSquare,
      {this.shoveGameMoveType = ShoveGameMoveType.move});

  void revertMove(ShoveGame shoveGame) {
    if (_didIncapacitatePiece != null) {
      _didIncapacitatePiece?.isIncapacitated = false;
    }

    if (_didShove) {
      revertShove();
    }
  }

  void shove(int x, int y, ShoveSquare shovedSquare, ShoveGame shoveGame,
      AudioPlayer audioPlayer) {
    if (shoveGame.isOutOfBounds(x, y)) {
      shoveGame.pieces.remove(shovedSquare.piece);
      audioPlayer.play(AssetSource('sounds/Yodascream.mp3'));
    } else {
      shovedSquare.piece?.isIncapacitated = true;
      shoveGame.getSquareByXY(x, y)?.piece = shovedSquare.piece;
    }

    _didShove = true;
    shovedSquare.piece = null;
  }

  void revertShove() {}

  void performLeap(ShoveGame shoveGame) {
    int midX = (oldSquare.x + newSquare.x) ~/ 2;
    int midY = ((oldSquare.y + newSquare.y) ~/ 2);
    ShoveSquare squareToIncapacitate = shoveGame.getSquareByXY(midX, midY)!;

    _didIncapacitatePiece = squareToIncapacitate.piece;
    squareToIncapacitate.piece?.isIncapacitated = true;
  }

  void throwPiece(ShoveGame shoveGame, AudioPlayer audioPlayer) {
    if (shoveGame.isOutOfBounds(newSquare.x, newSquare.y)) {
      audioPlayer.play(AssetSource('sounds/Yodascream.mp3'));
      shoveGame.pieces.remove(oldSquare.piece);
      shoveGame.getSquareByXY(oldSquare.x, oldSquare.y)!.piece = null;
    } else {
      oldSquare.piece!.isIncapacitated = true;
      shoveGame.getSquareByXY(newSquare.x, newSquare.y)!.piece =
          oldSquare.piece;
      shoveGame.getSquareByXY(oldSquare.x, oldSquare.y)!.piece = null;
      audioPlayer.play(AssetSource('sounds/ThrowSound.mp3'));
    }
  }

  void movePiece(ShoveGame shoveGame) {
    shoveGame.getSquareByXY(newSquare.x, newSquare.y)!.piece = oldSquare.piece;
    shoveGame.getSquareByXY(oldSquare.x, oldSquare.y)!.piece = null;
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
