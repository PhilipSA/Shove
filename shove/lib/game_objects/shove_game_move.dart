import 'package:shove/game_objects/shove_direction.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_square.dart';

class ShoveGameMove {
  final ShoveSquare oldSquare;
  final ShoveSquare newSquare;

  ShoveGameMove(this.oldSquare, this.newSquare);

  void shove(int x, int y, ShoveSquare shovedSquare, ShoveGame shoveGame) {
    if (shoveGame.isOutOfBounds(x, y)) {
      shoveGame.pieces.remove(shovedSquare.piece);
    } else {
      shovedSquare.piece?.isIncapacitated = true;
      shoveGame.getSquareByXY(x, y).piece = shovedSquare.piece;
    }

    shovedSquare.piece = null;
  }

  void performLeap(ShoveGame shoveGame) {
    int midX = (oldSquare.x + newSquare.x) ~/ 2;
    int midY = ((oldSquare.y + newSquare.y) ~/ 2);
    ShoveSquare squareToIncapacitate = shoveGame.getSquareByXY(midX, midY);

    squareToIncapacitate.piece?.isIncapacitated = true;
  }

  void movePiece(ShoveGame shoveGame) {
    shoveGame.getSquareByXY(newSquare.x, newSquare.y).piece = oldSquare.piece;
    shoveGame.getSquareByXY(oldSquare.x, oldSquare.y).piece = null;
  }

  void revertIncapacition(ShoveGame shoveGame) {
    for (var piece in shoveGame.pieces
        .where((element) => element.owner == shoveGame.currentPlayersTurn)) {
      piece.isIncapacitated = false;
    }
  }
}
