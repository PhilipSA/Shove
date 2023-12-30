import 'package:json_annotation/json_annotation.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/shove_player.dart';

part 'shove_player_dto.g.dart';

@JsonSerializable()
class ShovePlayerDto implements IPlayer {
  @override
  final String playerName;

  @override
  final bool isWhite;

  final String type;

  ShovePlayerDto(this.playerName, this.isWhite, this.type);

  factory ShovePlayerDto.fromPlayer(IPlayer player) {
    return ShovePlayerDto(
        player.playerName, player.isWhite, player.runtimeType.toString());
  }

  factory ShovePlayerDto.fromJson(Map<String, dynamic> json) =>
      _$ShovePlayerDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ShovePlayerDtoToJson(this);

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

  @override
  int get hashCode => playerName.hashCode ^ isWhite.hashCode;
}
