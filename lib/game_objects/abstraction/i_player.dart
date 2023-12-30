import 'package:shove/ai/min_max_ai.dart';
import 'package:shove/ai/random_ai.dart';
import 'package:shove/game_objects/dto/shove_player_dto.dart';
import 'package:shove/game_objects/shove_player.dart';

abstract class IPlayer {
  final String playerName;
  final bool isWhite;

  IPlayer(this.playerName, this.isWhite);

  factory IPlayer.fromDto(ShovePlayerDto dto) {
    switch (dto.type) {
      case 'ShovePlayer':
        return ShovePlayer(dto.playerName, dto.isWhite);
      case 'MinMaxAi':
        return MinMaxAi(dto.playerName, dto.isWhite);
      case 'RandomAi':
        return RandomAi(dto.playerName, dto.isWhite);
    }

    return ShovePlayer(dto.playerName, dto.isWhite);
  }

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
