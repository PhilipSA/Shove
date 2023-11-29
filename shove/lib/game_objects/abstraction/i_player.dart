abstract class IPlayer {
  final String playerName;
  final bool isWhite;

  IPlayer(this.playerName, this.isWhite);

  @override
  operator ==(Object other) {
    if (other is IPlayer) {
      return playerName == other.playerName && isWhite == other.isWhite;
    }
    return false;
  }

  @override
  int get hashCode => playerName.hashCode ^ isWhite.hashCode;
}
