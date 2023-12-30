import 'package:json_annotation/json_annotation.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';

import 'shove_piece_dto.dart';
import 'shove_player_dto.dart';
import 'shove_square_dto.dart';

part 'shove_game_move_dto.g.dart';

@JsonSerializable()
class ShoveGameMoveDto {
  final ShoveSquareDto oldSquare;
  final ShoveSquareDto newSquare;
  final ShoveGameMoveType shoveGameMoveType;
  final ShovePlayerDto madeBy;
  final ShoveSquareDto? throwerSquare;

  ShovePieceDto? _shovedPiece;
  ShoveSquareDto? _shovedToSquare;
  ShoveSquareDto? _leapedOverSquare;
  ShovePieceDto? _thrownPiece;

  ShoveGameMoveDto(
      this.oldSquare, this.newSquare, this.shoveGameMoveType, this.madeBy,
      {this.throwerSquare});

  factory ShoveGameMoveDto.fromGameMove(ShoveGameMove gameMove) {
    return ShoveGameMoveDto(
      ShoveSquareDto.fromSquare(gameMove.oldSquare),
      ShoveSquareDto.fromSquare(gameMove.newSquare),
      gameMove.shoveGameMoveType,
      ShovePlayerDto.fromPlayer(gameMove.madeBy),
      throwerSquare: gameMove.throwerSquare != null
          ? ShoveSquareDto.fromSquare(gameMove.throwerSquare!)
          : null,
    )
      .._shovedPiece = gameMove.shovedPiece != null
          ? ShovePieceDto.fromPiece(gameMove.shovedPiece!)
          : null
      .._shovedToSquare = gameMove.shovedToSquare != null
          ? ShoveSquareDto.fromSquare(gameMove.shovedToSquare!)
          : null
      .._leapedOverSquare = gameMove.leapedOverSquare != null
          ? ShoveSquareDto.fromSquare(gameMove.leapedOverSquare!)
          : null
      .._thrownPiece = gameMove.thrownPiece != null
          ? ShovePieceDto.fromPiece(gameMove.thrownPiece!)
          : null;
  }

  factory ShoveGameMoveDto.fromJson(Map<String, dynamic> json) =>
      _$ShoveGameMoveDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ShoveGameMoveDtoToJson(this);
}
