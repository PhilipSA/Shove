import 'package:audioplayers/audioplayers.dart';
import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_direction.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_square.dart';

class ShoveGame {
  final List<ShovePiece> pieces;
  final List<ShoveGameMove> allMadeMoves = [];

  static const int totalNumberOfRows = 10;
  static const int totalNumberOfColumns = 10;

  final IPlayer player1;
  final IPlayer player2;

  final bool isGameOver = false;
  final audioPlayer = AudioPlayer();

  IPlayer currentPlayersTurn;

  ShoveGame(this.player1, this.player2)
      : currentPlayersTurn = player1,
        pieces = getInitialPieces(player1, player2) {
    for (int currentCol = 1;
        currentCol < totalNumberOfColumns - 1;
        currentCol++) {
      getSquareByXY(2, currentCol)?.piece = pieces
          .where((element) =>
              element.owner == player2 && element.pieceType == PieceType.shover)
          .toList()[currentCol];
      getSquareByXY(7, currentCol)?.piece = pieces
          .where((element) =>
              element.owner == player1 && element.pieceType == PieceType.shover)
          .toList()[currentCol];
    }

    _addPieceToSquare(8, 1, ShovePiece.blocker(player1));
    _addPieceToSquare(8, 2, ShovePiece.leaper(player1));
    _addPieceToSquare(8, 3, ShovePiece.thrower(player1));
    _addPieceToSquare(8, 4, ShovePiece.thrower(player1));
    _addPieceToSquare(8, 5, ShovePiece.leaper(player1));
    _addPieceToSquare(8, 6, ShovePiece.thrower(player1));
    _addPieceToSquare(8, 7, ShovePiece.leaper(player1));
    _addPieceToSquare(8, 8, ShovePiece.blocker(player1));

    _addPieceToSquare(1, 1, ShovePiece.blocker(player2));
    _addPieceToSquare(1, 2, ShovePiece.leaper(player2));
    _addPieceToSquare(1, 3, ShovePiece.thrower(player2));
    _addPieceToSquare(1, 4, ShovePiece.thrower(player2));
    _addPieceToSquare(1, 5, ShovePiece.leaper(player2));
    _addPieceToSquare(1, 6, ShovePiece.thrower(player2));
    _addPieceToSquare(1, 7, ShovePiece.leaper(player2));
    _addPieceToSquare(1, 8, ShovePiece.blocker(player2));
  }

  static List<ShovePiece> getInitialPieces(IPlayer player1, IPlayer player2) {
    final player1Shovers =
        List.generate(9, (index) => ShovePiece.shover(player1));

    final player2Shovers =
        List.generate(9, (index) => ShovePiece.shover(player2));

    return player1Shovers..addAll(player2Shovers);
  }

  final _board = List<List<ShoveSquare>>.generate(
      totalNumberOfRows,
      (i) => List<ShoveSquare>.generate(totalNumberOfColumns,
          (index) => ShoveSquare(i, index % totalNumberOfRows, null),
          growable: false),
      growable: false);

  bool validateThrow(ShoveSquare oldSquare, ShoveSquare newSquare) {
    if (isOutOfBounds(newSquare.x, newSquare.y)) {
      return false;
    }

    if (getSquareByXY(newSquare.x, newSquare.y)?.piece != null) {
      return false;
    }

    return true;
  }

  bool validateMove(
      ShoveSquare oldSquare, ShoveSquare newSquare, ShoveGameMoveType type) {
    if (type == ShoveGameMoveType.thrown) {
      return validateThrow(oldSquare, newSquare);
    }

    if (oldSquare.x == newSquare.x && oldSquare.y == newSquare.y) {
      return false;
    }

    if (oldSquare.piece == null) {
      return false;
    }

    if (oldSquare.piece?.isIncapacitated ?? false) {
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
        if (getSquareByXY(newSquare.x, newSquare.y)!.piece?.pieceType ==
            PieceType.blocker) {
          return false;
        }

        if ((oldSquare.x - newSquare.x).abs() > 0 &&
            (oldSquare.y - newSquare.y).abs() > 0) {
          return false;
        }

        var direction = calculateShoveDirection(oldSquare, newSquare);
        if (direction == null) {
          return false;
        }

        if (getSquareByXY(newSquare.x, newSquare.y)?.piece != null) {
          // Shovers cannot shove if it results in a collision with another piece
          if (shoveResultsInCollision(direction, newSquare.x, newSquare.y)) {
            return false;
          }
        }

      case PieceType.blocker:
        if ((oldSquare.x - newSquare.x).abs() > 0 &&
            (oldSquare.y - newSquare.y).abs() > 0) {
          return false;
        }

        if ((oldSquare.x - newSquare.x).abs() > 2 ||
            (oldSquare.y - newSquare.y).abs() > 2) {
          return false;
        }

        // Check if blocker is attempting to jump over a piece
        int midX = (oldSquare.x + newSquare.x) ~/ 2;
        int midY = ((oldSquare.y + newSquare.y) ~/ 2);
        ShoveSquare midSquare = getSquareByXY(midX, midY)!;
        if (midSquare.piece != null) {
          return false;
        }

        if (getSquareByXY(newSquare.x, newSquare.y)?.piece != null) {
          return false;
        }
      case PieceType.leaper:
        if ((oldSquare.x - newSquare.x).abs() > 0 &&
            (oldSquare.y - newSquare.y).abs() > 0) {
          return false;
        }

        // Leapers cannot land on pieces
        if (getSquareByXY(newSquare.x, newSquare.y)?.piece != null) {
          return false;
        }

        // Check if there is a piece to jump over
        int midX = (oldSquare.x + newSquare.x) ~/ 2;
        int midY = ((oldSquare.y + newSquare.y) ~/ 2);
        ShoveSquare midSquare = getSquareByXY(midX, midY)!;

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

      case PieceType.thrower:
        if ((oldSquare.x - newSquare.x).abs() > 1 ||
            (oldSquare.y - newSquare.y).abs() > 1) {
          return false;
        }

        if (getSquareByXY(newSquare.x, newSquare.y)?.piece != null) {
          return false;
        }

      default:
        throw Exception("Piece type not implemented");
    }

    if (getSquareByXY(newSquare.x, newSquare.y)?.piece?.owner ==
        oldSquare.piece?.owner) {
      return false;
    }

    return true;
  }

  void _addPieceToSquare(int x, int y, ShovePiece shovePiece) {
    final piece = shovePiece;
    getSquareByXY(x, y)?.piece = piece;
    pieces.add(piece);
  }

  ShoveSquare? getSquareByXY(int x, int y) {
    if (x < 0 || y < 0 || x >= _board.length || y >= _board.length) {
      return null;
    }

    return _board.elementAtOrNull(x)?.elementAtOrNull(y);
  }

  bool isOutOfBounds(int x, int y) {
    //Edges are a dead zone
    return x < 1 || x >= _board.length - 1 || y < 1 || y >= _board.length - 1;
  }

  Future<void> procceedGameState() async {
    final isGameOver = checkIfGameIsOver();

    if (currentPlayersTurn is IAi && !isGameOver) {
      final aiMove = await (currentPlayersTurn as IAi).makeMove(this);
      await move(aiMove);
    }
  }

  Future<void> move(ShoveGameMove shoveGameMove) async {
    if (shoveGameMove.shoveGameMoveType == ShoveGameMoveType.thrown) {
      shoveGameMove.throwPiece(this);
    }

    // you cannot move into your own pieces, so we can safely assume that this is always an opponent
    var opponentSquare = shoveGameMove.newSquare;

    if (opponentSquare.piece != null &&
        shoveGameMove.oldSquare.piece?.pieceType == PieceType.shover) {
      var shoveDirection = calculateShoveDirection(
          shoveGameMove.oldSquare, shoveGameMove.newSquare);
      if (shoveDirection == null) {
        final playerName = shoveGameMove.oldSquare.piece?.owner.playerName;
        throw Exception('$playerName made an invalid move!');
      }

      switch (shoveDirection) {
        case ShoveDirection.xPositive:
          shoveGameMove.shove(shoveGameMove.newSquare.x + 1,
              shoveGameMove.newSquare.y, opponentSquare, this);
        case ShoveDirection.xNegative:
          shoveGameMove.shove(shoveGameMove.newSquare.x - 1,
              shoveGameMove.newSquare.y, opponentSquare, this);
        case ShoveDirection.yPositive:
          shoveGameMove.shove(shoveGameMove.newSquare.x,
              shoveGameMove.newSquare.y + 1, opponentSquare, this);
        case ShoveDirection.yNegative:
          shoveGameMove.shove(shoveGameMove.newSquare.x,
              shoveGameMove.newSquare.y - 1, opponentSquare, this);
      }

      audioPlayer.play(AssetSource('sounds/Bonk_1.mp3'));
    }

    if (shoveGameMove.oldSquare.piece?.pieceType == PieceType.leaper) {
      shoveGameMove.performLeap(this);
    }

    shoveGameMove.movePiece(this);
    shoveGameMove.revertIncapacition(this);

    currentPlayersTurn = currentPlayersTurn.isWhite ? player2 : player1;

    allMadeMoves.add(shoveGameMove);
    //printBoard();
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

  bool shoveResultsInCollision(ShoveDirection direction, int x, int y) {
    return switch (direction) {
      ShoveDirection.xPositive => getSquareByXY(x + 1, y)?.piece != null,
      ShoveDirection.xNegative => getSquareByXY(x - 1, y)?.piece != null,
      ShoveDirection.yPositive => getSquareByXY(x, y + 1)?.piece != null,
      ShoveDirection.yNegative => getSquareByXY(x, y - 1)?.piece != null,
    };
  }

  bool checkIfGameIsOver() {
    return pieces.where((element) => element.owner == player1).isEmpty ||
        pieces.where((element) => element.owner == player1).isEmpty;
  }

  List<ShoveGameMove> getAllLegalMoves() {
    List<ShoveGameMove> legals = [];

    for (var row in _board) {
      for (var square in row) {
        if (square.piece != null && square.piece!.owner == currentPlayersTurn) {
          for (int x = 0; x < totalNumberOfRows; x++) {
            for (int y = 0; y < totalNumberOfColumns; y++) {
              final newSquare = getSquareByXY(x, y);
              if (newSquare != null &&
                  validateMove(square, newSquare, ShoveGameMoveType.move)) {
                legals.add(ShoveGameMove(square, newSquare));
              }
            }
          }
        }
      }
    }

    return legals;
  }

  void undoLastMove() {
    if (allMadeMoves.isEmpty) return;

    var lastMove = allMadeMoves.removeLast();

    lastMove.revertMove(this);

    // Switch the current player turn back
    currentPlayersTurn = currentPlayersTurn.isWhite ? player2 : player1;
  }

  bool shoveSquareIsValidTargetForThrow(ShoveSquare square) {
    if (square.piece == null) return false;
    final neighbors = getAllNeighborSquares(square);

    if (square.piece?.owner == currentPlayersTurn) return false;

    return neighbors.any((element) {
      final isOpponentsThrower =
          element.piece?.pieceType == PieceType.thrower &&
              element.piece?.owner != currentPlayersTurn;
      final isMyThrowerAndTargetIsOpponentsPiece =
          element.piece?.pieceType == PieceType.thrower &&
              element.piece?.owner == currentPlayersTurn &&
              square.piece?.owner != currentPlayersTurn;

      return !isOpponentsThrower && isMyThrowerAndTargetIsOpponentsPiece;
    });
  }

  List<ShoveSquare> getAllNeighborSquares(ShoveSquare square) {
    List<ShoveSquare> neighbors = [];

    for (int x = square.x - 1; x <= square.x + 1; x++) {
      for (int y = square.y - 1; y <= square.y + 1; y++) {
        if (x == square.x && y == square.y) continue;

        final neighbor = getSquareByXY(x, y);
        if (neighbor != null) {
          neighbors.add(neighbor);
        }
      }
    }

    return neighbors;
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
