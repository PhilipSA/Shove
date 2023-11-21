import 'package:flutter/widgets.dart';
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_direction.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/game_objects/shove_square.dart';

class ShoveGame {
  final List<ShovePiece> pieces;

  static const int totalNumberOfRows = 8;
  static const int totalNumberOfColumns = 8;

  final IPlayer player1;
  final IPlayer player2;

  IPlayer currentPlayersTurn;

  ShoveGame(this.player1, this.player2)
      : currentPlayersTurn = player1,
        pieces = getInitialPieces(player1, player2) {
    for (int currentCol = 0; currentCol < totalNumberOfColumns; currentCol++) {
      getSquareByXY(0, currentCol).piece = pieces
          .where((element) => element.owner == player2)
          .toList()[currentCol];
      getSquareByXY(7, currentCol).piece = pieces
          .where((element) => element.owner == player1)
          .toList()[currentCol];
    }
  }

  static List<ShovePiece> getInitialPieces(IPlayer player1, IPlayer player2) {
    final player1Pieces = List.generate(
        8,
        (index) => ShovePiece(PieceType.shover,
            Image.asset('assets/textures/shover.png'), player1));

    final player2Pieces = List.generate(
        8,
        (index) => ShovePiece(PieceType.shover,
            Image.asset('assets/textures/shover.png'), player2));

    return player1Pieces..addAll(player2Pieces);
  }

  final _board = List<List<ShoveSquare>>.generate(
      totalNumberOfRows,
      (i) => List<ShoveSquare>.generate(
          totalNumberOfColumns, (index) => ShoveSquare(i, index % 8, null),
          growable: false),
      growable: false);

  bool validateMove(ShoveSquare oldSquare, ShoveSquare newSquare) {
    if (oldSquare.piece == null) {
      return false;
    }

    if (isOutOfBounds(newSquare.x, newSquare.y)) {
      return false;
    }

    if (oldSquare.piece!.pieceType == PieceType.shover) {
      if ((oldSquare.x - newSquare.x).abs() > 1) {
        return false;
      }

      if ((oldSquare.y - newSquare.y).abs() > 1) {
        return false;
      }

      // Shovers cannot move horizontally
      if ((oldSquare.x - newSquare.x).abs() > 0 &&
          (oldSquare.y - newSquare.y).abs() > 0) {
        return false;
      }
    }

    if (getSquareByXY(newSquare.x, newSquare.y).piece?.owner ==
        oldSquare.piece?.owner) {
      return false;
    }

    return true;
  }

  ShoveSquare getSquareByXY(int x, int y) {
    return _board[x][y];
  }

  bool isOutOfBounds(int x, int y) {
    return x < 0 || x >= _board.length || y < 0 || y >= _board.length;
  }

  void move(ShoveSquare oldSquare, ShoveSquare newSquare) {
    var shoveDirection = calculateShoveDirection(oldSquare, newSquare);
    if (shoveDirection == null) {
      return;
    }

    var opponentSquare = getSquareByXY(newSquare.x, newSquare.y);

    // you cannot shove your own pieces, so we can safely assume that this is always an opponent
    if (opponentSquare.piece != null) {

      // todo: check if the shove affects other pieces nearby

      switch (shoveDirection) {
        case ShoveDirection.xPositive:
          shove(newSquare.x + 1, newSquare.y, opponentSquare);
        case ShoveDirection.xNegative:
          shove(newSquare.x - 1, newSquare.y, opponentSquare);
        case ShoveDirection.yPositive:
          shove(newSquare.x, newSquare.y + 1, opponentSquare);
        case ShoveDirection.yNegative:
          shove(newSquare.x, newSquare.y - 1, opponentSquare);
      }
    }

    getSquareByXY(newSquare.x, newSquare.y).piece = oldSquare.piece;
    getSquareByXY(oldSquare.x, oldSquare.y).piece = null;

    for (var piece
        in pieces.where((element) => element.owner == currentPlayersTurn)) {
      piece.isIncapacitated = false;
    }

    currentPlayersTurn = currentPlayersTurn.isWhite ? player2 : player1;

    if (currentPlayersTurn is IAi) {
      (currentPlayersTurn as IAi).makeMove(this);
    }

    printBoard();
  }

  ShoveDirection? calculateShoveDirection(
      ShoveSquare oldSquare, ShoveSquare newSquare) {
    if (newSquare.x > oldSquare.x) {
      return ShoveDirection.xPositive;
    } else if (newSquare.x < oldSquare.x) {
      return ShoveDirection.xNegative;
    }

    if (newSquare.y > oldSquare.y) {
      return ShoveDirection.yPositive;
    } else if (newSquare.y < oldSquare.y) {
      return ShoveDirection.yNegative;
    }

    return null;
  }

  void shove(int x, int y, ShoveSquare shovedSquare) {
    if (isOutOfBounds(x, y)) {
      pieces.remove(shovedSquare.piece);
    } else {
      shovedSquare.piece?.isIncapacitated = true;
      getSquareByXY(x, y).piece = shovedSquare.piece;
    }

    shovedSquare.piece = null;
  }

  List<(ShoveSquare, ShoveSquare)> getAllLegalMoves() {
    List<(ShoveSquare, ShoveSquare)> legals = [];

    Stopwatch stopwatch = Stopwatch()..start();

    for (var row in _board) {
      for (var square in row) {
        if (square.piece != null && square.piece!.owner == currentPlayersTurn) {
          for (int x = 0; x < totalNumberOfRows; x++) {
            for (int y = 0; y < totalNumberOfColumns; y++) {
              if (validateMove(square, getSquareByXY(x, y))) {
                legals.add((square, getSquareByXY(x, y)));
              }
            }
          }
        }
      }
    }

    print('listAllLegals took ${stopwatch.elapsed}');

    return legals;
  }

  void printBoard() {
    for (var row in _board) {
      String rowDisplay = '';
      for (var square in row) {
        String pieceDisplay = square.piece != null ? "P" : ".";
        rowDisplay += '$pieceDisplay\t'; // Building the row string
      }
      print(rowDisplay); // Printing the entire row
    }
  }
}
