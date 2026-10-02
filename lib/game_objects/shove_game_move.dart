import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_game_move_dto.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_square.dart';
import 'package:shove/resources/shove_assets.dart';

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

  Set<String>? _stunnedBefore;
  ({IPlayer? winner, bool isOver})? _gameOverStateBefore;
  GameOverReason? _gameOverReasonBefore;

  /// True when this move pushed a piece off the board.
  bool get eliminatedPiece => shovedPiece != null && shovedToSquare == null;

  ShoveGameMove(
    this.oldSquare,
    this.newSquare,
    this.madeBy, {
    this.throwerSquare,
  }) : shoveGameMoveType = throwerSquare != null
           ? ShoveGameMoveType.thrown
           : ShoveGameMoveType.move;

  void captureStateBefore(ShoveGame shoveGame) {
    _stunnedBefore = {
      for (final piece in shoveGame.pieces.values)
        if (piece.isIncapacitated) piece.id,
    };
    _gameOverStateBefore = shoveGame.gameOverState;
    _gameOverReasonBefore = shoveGame.gameOverReason;
  }

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

    final stunnedBefore = _stunnedBefore;
    if (stunnedBefore != null) {
      for (final piece in shoveGame.pieces.values) {
        piece.isIncapacitated = stunnedBefore.contains(piece.id);
      }
      shoveGame.gameOverState = _gameOverStateBefore;
      shoveGame.gameOverReason = _gameOverReasonBefore;
    }
  }

  factory ShoveGameMove.fromDto(ShoveGameMoveDto dto) {
    return ShoveGameMove(
      ShoveSquare.fromDto(dto.oldSquare),
      ShoveSquare.fromDto(dto.newSquare),
      IPlayer.fromDto(dto.madeBy),
      throwerSquare: dto.throwerSquare != null
          ? ShoveSquare.fromDto(dto.throwerSquare!)
          : null,
    );
  }

  AudioAssets _pieceOutOfBounds(ShoveGame shoveGame, ShovePiece piece) {
    shoveGame.pieces.remove(piece.id);
    return AudioAssets.scream;
  }

  void _revertPieceOutOfBounds(ShoveGame shoveGame, ShovePiece piece) {
    final wasYeeted = shoveGame.pieces[piece.id] == null;

    if (wasYeeted) {
      shoveGame.pieces[piece.id] = piece;
    }
  }

  AudioAssets shove(
    int x,
    int y,
    ShoveSquare shovedSquare,
    ShoveGame shoveGame,
  ) {
    final AudioAssets audioToPlay;

    final piece = shoveGame.pieces[shovedSquare.pieceId];

    if (shoveGame.isOutOfBounds(x, y)) {
      audioToPlay = _pieceOutOfBounds(shoveGame, piece!);
    } else {
      piece?.isIncapacitated = true;
      final squareToShoveTo = shoveGame.getSquareByXY(x, y);
      squareToShoveTo?.pieceId = shovedSquare.pieceId;
      shovedToSquare = squareToShoveTo;
      audioToPlay = AudioAssets.bonk;
    }

    shovedPiece = piece;
    shovedSquare.pieceId = null;
    return audioToPlay;
  }

  void _revertShove(ShoveGame shoveGame) {
    _revertPieceOutOfBounds(shoveGame, shovedPiece!);
    shovedPiece?.isIncapacitated = false;
    shovedToSquare?.pieceId = null;
    shoveGame.getSquareByXY(newSquare.x, newSquare.y)!.pieceId =
        shovedPiece?.id;
  }

  void performLeap(ShoveGame shoveGame) {
    final isLeap =
        (oldSquare.x - newSquare.x).abs() == 2 ||
        (oldSquare.y - newSquare.y).abs() == 2;
    if (!isLeap) return;

    final squareLeapedOver = shoveGame.getSquareByXY(
      (oldSquare.x + newSquare.x) ~/ 2,
      (oldSquare.y + newSquare.y) ~/ 2,
    )!;
    final piece = shoveGame.pieces[squareLeapedOver.pieceId];

    // Only opponents are stunned by a leap
    if (piece != null && piece.owner != madeBy) {
      piece.isIncapacitated = true;
      leapedOverSquare = squareLeapedOver;
    }
  }

  void _revertLeap(ShoveGame shoveGame) {
    final piece = shoveGame.pieces[leapedOverSquare?.pieceId];

    piece?.isIncapacitated = false;
  }

  AudioAssets throwPiece(ShoveGame shoveGame) {
    thrownPiece = shoveGame.pieces[oldSquare.pieceId];

    thrownPiece!.isIncapacitated = true;
    shoveGame.getSquareByXY(newSquare.x, newSquare.y)!.pieceId =
        oldSquare.pieceId;
    shoveGame.getSquareByXY(oldSquare.x, oldSquare.y)!.pieceId = null;
    return AudioAssets.throwSound;
  }

  void _revertThrow(ShoveGame shoveGame) {
    thrownPiece!.isIncapacitated = false;
    oldSquare.pieceId = thrownPiece?.id;
    newSquare.pieceId = null;
  }

  void movePiece(ShoveGame shoveGame) {
    shoveGame.getSquareByXY(newSquare.x, newSquare.y)!.pieceId =
        oldSquare.pieceId;
    shoveGame.getSquareByXY(oldSquare.x, oldSquare.y)!.pieceId = null;
  }

  void _revertMovePiece(ShoveGame shoveGame) {
    shoveGame.getSquareByXY(oldSquare.x, oldSquare.y)!.pieceId =
        newSquare.pieceId;
    shoveGame.getSquareByXY(newSquare.x, newSquare.y)!.pieceId = null;
  }

  void revertIncapacition(ShoveGame shoveGame) {
    for (var piece in shoveGame.pieces.values.where(
      (element) =>
          element.owner == shoveGame.currentPlayersTurn &&
          element.isIncapacitated,
    )) {
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
