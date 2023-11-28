import 'package:json_annotation/json_annotation.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_piece_dto.dart';
import 'package:shove/game_objects/dto/shove_square_dto.dart';
import 'package:shove/game_objects/shove_game_move_type.dart';

part 'shove_game_move_dto.g.dart';

@JsonSerializable()
class ShoveGameMoveDto {
  final ShoveSquareDto oldSquare;
  final ShoveSquareDto newSquare;
  final ShoveGameMoveType shoveGameMoveType;
  final IPlayer madeBy;
  final ShoveSquareDto? throwerSquare;

  ShovePieceDto? _shovedPiece;
  ShoveSquareDto? _shovedToSquare;
  ShoveSquareDto? _leapedOverSquare;
  ShovePieceDto? _thrownPiece;

  ShoveGameMoveDto(this.oldSquare, this.newSquare, this.madeBy,
      {this.throwerSquare});

  factory ShoveGameMoveDto.fromJson(Map<String, dynamic> json) =>
      _$ShoveGameMoveDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ShoveGameMoveDtoToJson(this);
}
