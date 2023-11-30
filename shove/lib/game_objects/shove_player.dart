import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_player_dto.dart';

class ShovePlayer extends IPlayer {
  ShovePlayer(super.playerName, super.isWhite);

  @override
  int get hashCode => playerName.hashCode ^ isWhite.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is ShovePlayer) {
      return playerName == other.playerName && isWhite == other.isWhite;
    }
    if (other is ShovePlayerDto) {
      return playerName == other.playerName && isWhite == other.isWhite;
    }
    return false;
  }
}
