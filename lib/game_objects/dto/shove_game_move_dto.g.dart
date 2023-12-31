// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shove_game_move_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShoveGameMoveDto _$ShoveGameMoveDtoFromJson(Map<String, dynamic> json) =>
    ShoveGameMoveDto(
      ShoveSquareDto.fromJson(json['oldSquare'] as Map<String, dynamic>),
      ShoveSquareDto.fromJson(json['newSquare'] as Map<String, dynamic>),
      $enumDecode(_$ShoveGameMoveTypeEnumMap, json['shoveGameMoveType']),
      ShovePlayerDto.fromJson(json['madeBy'] as Map<String, dynamic>),
      throwerSquare: json['throwerSquare'] == null
          ? null
          : ShoveSquareDto.fromJson(
              json['throwerSquare'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ShoveGameMoveDtoToJson(ShoveGameMoveDto instance) =>
    <String, dynamic>{
      'oldSquare': instance.oldSquare,
      'newSquare': instance.newSquare,
      'shoveGameMoveType':
          _$ShoveGameMoveTypeEnumMap[instance.shoveGameMoveType]!,
      'madeBy': instance.madeBy,
      'throwerSquare': instance.throwerSquare,
    };

const _$ShoveGameMoveTypeEnumMap = {
  ShoveGameMoveType.move: 'move',
  ShoveGameMoveType.thrown: 'thrown',
};
