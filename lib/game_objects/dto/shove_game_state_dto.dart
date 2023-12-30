import 'package:json_annotation/json_annotation.dart';
import 'package:shove/game_objects/shove_game.dart';

import 'shove_game_move_dto.dart';
import 'shove_piece_dto.dart';
import 'shove_player_dto.dart';
import 'shove_square_dto.dart';

part 'shove_game_state_dto.g.dart';

@JsonSerializable()
class ShoveGameStateDto {
  final Map<String, ShoveSquareDto> board;
  final List<ShovePieceDto> pieces;
  final List<ShoveGameMoveDto> allMadeMoves;

  final ShovePlayerDto player1;
  final ShovePlayerDto player2;

  ShovePlayerDto currentPlayersTurn;
  ({ShovePlayerDto? winner, bool isOver})? gameOverState;

  ShoveGameStateDto(this.board, this.pieces, this.allMadeMoves, this.player1,
      this.player2, this.currentPlayersTurn, this.gameOverState);

  factory ShoveGameStateDto.fromGame(ShoveGame shoveGame) {
    return ShoveGameStateDto(
        Map.from(shoveGame.board.map((key, value) =>
            MapEntry('${key.$1},${key.$2}', ShoveSquareDto.fromSquare(value)))),
        shoveGame.pieces.map((e) => ShovePieceDto.fromPiece(e)).toList(),
        shoveGame.allMadeMoves
            .map((e) => ShoveGameMoveDto.fromGameMove(e))
            .toList(),
        ShovePlayerDto.fromPlayer(shoveGame.player1),
        ShovePlayerDto.fromPlayer(shoveGame.player2),
        ShovePlayerDto.fromPlayer(shoveGame.currentPlayersTurn),
        shoveGame.gameOverState?.winner != null
            ? (
                isOver: shoveGame.gameOverState!.isOver,
                winner:
                    ShovePlayerDto.fromPlayer(shoveGame.gameOverState!.winner!)
              )
            : null);
  }

  factory ShoveGameStateDto.fromJson(Map<String, dynamic> json) =>
      _$ShoveGameStateDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ShoveGameStateDtoToJson(this);
}
