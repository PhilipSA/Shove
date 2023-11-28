import 'package:json_annotation/json_annotation.dart';

part 'shove_player_dto.g.dart';

@JsonSerializable()
class ShovePlayerDto {
  final String playerId;
  final bool isWhite;

  ShovePlayerDto(this.playerId, this.isWhite);

  factory ShovePlayerDto.fromJson(Map<String, dynamic> json) =>
      _$ShovePlayerDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ShovePlayerDtoToJson(this);
}
