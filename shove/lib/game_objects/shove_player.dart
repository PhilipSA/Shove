import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_player_dto.dart';

class ShovePlayer extends IPlayer {
  ShovePlayer(super.playerName, super.isWhite);

  factory ShovePlayer.fromDto(ShovePlayerDto dto) {
    return ShovePlayer(dto.playerName, dto.isWhite);
  }
}
