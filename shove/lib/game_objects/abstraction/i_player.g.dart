// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'i_player.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IPlayer _$IPlayerFromJson(Map<String, dynamic> json) => IPlayer(
      json['playerName'] as String,
      json['isWhite'] as bool,
    );

Map<String, dynamic> _$IPlayerToJson(IPlayer instance) => <String, dynamic>{
      'playerName': instance.playerName,
      'isWhite': instance.isWhite,
    };
