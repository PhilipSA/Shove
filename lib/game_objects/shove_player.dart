import 'package:shove/game_objects/abstraction/i_player.dart';

class ShovePlayer extends IPlayer {
  ShovePlayer(super.playerName, super.isWhite);

  @override
  int get hashCode => playerName.hashCode ^ isWhite.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is ShovePlayer) {
      return playerName == other.playerName && isWhite == other.isWhite;
    }
    return false;
  }
}
