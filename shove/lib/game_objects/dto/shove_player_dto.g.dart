// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shove_player_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShovePlayerDto _$ShovePlayerDtoFromJson(Map<String, dynamic> json) =>
    ShovePlayerDto(
      json['playerId'] as String,
      json['isWhite'] as bool,
    );

Map<String, dynamic> _$ShovePlayerDtoToJson(ShovePlayerDto instance) =>
    <String, dynamic>{
      'playerId': instance.playerId,
      'isWhite': instance.isWhite,
    };
