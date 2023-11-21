import 'package:flutter_svg/svg.dart';
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_direction.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_square.dart';

class ShoveGame {
  final List<ShovePiece> pieces;

  static const int totalNumberOfRows = 8;
  static const int totalNumberOfColumns = 8;

  final IPlayer player1;
  final IPlayer player2;

  final bool isGameOver = false;

  IPlayer currentPlayersTurn;

  ShoveGame(this.player1, this.player2)
      : currentPlayersTurn = player1,
        pieces = getInitialPieces(player1, player2) {
    for (int currentCol = 0; currentCol < totalNumberOfColumns; currentCol++) {
      getSquareByXY(0, currentCol).piece = pieces
          .where((element) =>
              element.owner == player2 && element.pieceType == PieceType.shover)
          .toList()[currentCol];
      getSquareByXY(7, currentCol).piece = pieces
          .where((element) =>
              element.owner == player1 && element.pieceType == PieceType.shover)
          .toList()[currentCol];
    }

    final blockerPiece = ShovePiece(PieceType.blocker,
        SvgPicture.asset('assets/textures/ankare.svg'), player1);
    getSquareByXY(6, 0).piece = blockerPiece;
    pieces.add(blockerPiece);

    final leaperPiece = ShovePiece(PieceType.leaper,
        SvgPicture.asset('assets/textures/hoppare.svg'), player1);
    getSquareByXY(6, 1).piece = leaperPiece;
    pieces.add(leaperPiece);
  }

  static List<ShovePiece> getInitialPieces(IPlayer player1, IPlayer player2) {
    final player1Shovers = List.generate(
        8,
        (index) => ShovePiece(
            PieceType.shover,
            SvgPicture.asset(
              'assets/textures/knuffare.svg',
            ),
            player1));

    final player2Shovers = List.generate(
        8,
        (index) => ShovePiece(
            PieceType.shover,
            SvgPicture.asset(
              'assets/textures/knuffare.svg',
            ),
            player2));

    return player1Shovers..addAll(player2Shovers);
  }

  final _board = List<List<ShoveSquare>>.generate(
      totalNumberOfRows,
      (i) => List<ShoveSquare>.generate(
          totalNumberOfColumns, (index) => ShoveSquare(i, index % 8, null),
          growable: false),
      growable: false);

  bool validateMove(ShoveSquare oldSquare, ShoveSquare newSquare) {
    if (oldSquare.x == newSquare.x && oldSquare.y == newSquare.y) {
      return false;
    }

    if (oldSquare.piece == null) {
      return false;
    }

    if (isOutOfBounds(newSquare.x, newSquare.y)) {
      return false;
    }

    switch (oldSquare.piece!.pieceType) {
      case PieceType.shover:
        if ((oldSquare.x - newSquare.x).abs() > 1) {
          return false;
        }

        if ((oldSquare.y - newSquare.y).abs() > 1) {
          return false;
        }

        // Shovers cannot move diagonally
        if ((oldSquare.x - newSquare.x).abs() > 0 &&
            (oldSquare.y - newSquare.y).abs() > 0) {
          return false;
        }

        // Shovers cannot shove blockers
        if (getSquareByXY(newSquare.x, newSquare.y).piece?.pieceType ==
            PieceType.blocker) {
          return false;
        }
      case PieceType.blocker:
        if ((oldSquare.x - newSquare.x).abs() > 2) {
          return false;
        }

        if ((oldSquare.y - newSquare.y).abs() > 2) {
          return false;
        }

        if (getSquareByXY(newSquare.x, newSquare.y).piece != null) {
          return false;
        }
      case PieceType.leaper:

        // Leapers cannot move diagonally
        if ((oldSquare.x - newSquare.x).abs() > 0 &&
            (oldSquare.y - newSquare.y).abs() > 0) {
          return false;
        }

        // Leapers cannot land on pieces
        if (getSquareByXY(newSquare.x, newSquare.y).piece != null) {
          return false;
        }

        // Check if there is a piece to jump over
        int midX = (oldSquare.x + newSquare.x) ~/ 2;
        int midY = ((oldSquare.y + newSquare.y) ~/ 2);
        ShoveSquare midSquare = getSquareByXY(midX, midY);

        if (midSquare.piece == null) {
          // Can only move one square when not jumping
          if ((oldSquare.x - newSquare.x).abs() > 1 ||
              (oldSquare.y - newSquare.y).abs() > 1) {
            return false;
          }
        } else {
          if ((oldSquare.x - newSquare.x).abs() > 2 ||
              (oldSquare.y - newSquare.y).abs() > 2) {
            return false;
          }
        }

      default:
        throw Exception("Piece type not implemented");
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

  Future<void> procceedGameState() async {
    final isGameOver = checkIfGameIsOver();

    if (currentPlayersTurn is IAi && !isGameOver) {
      final aiMove = await (currentPlayersTurn as IAi).makeMove(this);
      await move(aiMove.$1, aiMove.$2);
    }
  }

  Future<void> move(ShoveSquare oldSquare, ShoveSquare newSquare) async {
    // you cannot move into your own pieces, so we can safely assume that this is always an opponent
    var opponentSquare = getSquareByXY(newSquare.x, newSquare.y);

    if (opponentSquare.piece != null &&
        oldSquare.piece?.pieceType == PieceType.shover) {
      // todo: check if the shove affects other pieces nearby

      var shoveDirection = calculateShoveDirection(oldSquare, newSquare);
      if (shoveDirection == null) {
        final playerName = oldSquare.piece?.owner.playerName;
        throw Exception('$playerName made an invalid move!');
      }

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

    if (oldSquare.piece?.pieceType == PieceType.leaper) {
      int midX = (oldSquare.x + newSquare.x) ~/ 2;
      int midY = ((oldSquare.y + newSquare.y) ~/ 2);
      ShoveSquare squareToIncapacitate = getSquareByXY(midX, midY);

      squareToIncapacitate.piece?.isIncapacitated = true;
    }

    getSquareByXY(newSquare.x, newSquare.y).piece = oldSquare.piece;
    getSquareByXY(oldSquare.x, oldSquare.y).piece = null;

    for (var piece
        in pieces.where((element) => element.owner == currentPlayersTurn)) {
      piece.isIncapacitated = false;
    }

    currentPlayersTurn = currentPlayersTurn.isWhite ? player2 : player1;

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

  bool checkIfGameIsOver() {
    return pieces.where((element) => element.owner == player1).isEmpty ||
        pieces.where((element) => element.owner == player1).isEmpty;
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
