import 'package:json_annotation/json_annotation.dart';

part 'i_player.g.dart';

@JsonSerializable()
abstract class IPlayer {
  String playerName;
  bool isWhite;

  IPlayer(this.playerName, this.isWhite);
}
