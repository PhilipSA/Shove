import 'package:json_annotation/json_annotation.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_game_move_dto.dart';
import 'package:shove/game_objects/dto/shove_piece_dto.dart';
import 'package:shove/game_objects/dto/shove_square_dto.dart';

part 'shove_game_state_dto.g.dart';

@JsonSerializable()
class ShoveGameStateDto {
  final List<List<ShoveSquareDto>> board;
  final List<ShovePieceDto> pieces;
  final List<ShoveGameMoveDto> allMadeMoves;

  final IPlayer player1;
  final IPlayer player2;

  IPlayer currentPlayersTurn;
  ({IPlayer? winner, bool isOver})? gameOverState;

  ShoveGameStateDto(this.board, this.pieces, this.allMadeMoves, this.player1,
      this.player2, this.currentPlayersTurn, this.gameOverState);

  factory ShoveGameStateDto.fromJson(Map<String, dynamic> json) =>
      _$ShoveGameStateDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ShoveGameStateDtoToJson(this);
}
