// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shove_player_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShovePlayerDto _$ShovePlayerDtoFromJson(Map<String, dynamic> json) =>
    ShovePlayerDto(
      json['playerName'] as String,
      json['isWhite'] as bool,
      json['type'] as String,
    );

Map<String, dynamic> _$ShovePlayerDtoToJson(ShovePlayerDto instance) =>
    <String, dynamic>{
      'playerName': instance.playerName,
      'isWhite': instance.isWhite,
      'type': instance.type,
    };
