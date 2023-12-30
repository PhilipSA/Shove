// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shove_piece_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShovePieceDto _$ShovePieceDtoFromJson(Map<String, dynamic> json) =>
    ShovePieceDto(
      $enumDecode(_$PieceTypeEnumMap, json['pieceType']),
      json['texture'] as String,
      json['isIncapacitated'] as bool,
      ShovePlayerDto.fromJson(json['owner'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ShovePieceDtoToJson(ShovePieceDto instance) =>
    <String, dynamic>{
      'pieceType': _$PieceTypeEnumMap[instance.pieceType]!,
      'texture': instance.texture,
      'isIncapacitated': instance.isIncapacitated,
      'owner': instance.owner,
    };

const _$PieceTypeEnumMap = {
  PieceType.shover: 'shover',
  PieceType.thrower: 'thrower',
  PieceType.blocker: 'blocker',
  PieceType.leaper: 'leaper',
};
