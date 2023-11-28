// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shove_piece_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShovePieceDto _$ShovePieceDtoFromJson(Map<String, dynamic> json) =>
    ShovePieceDto(
      json['pieceType'] as String,
      json['texture'] as String,
      json['isIncapacitated'] as bool,
      json['owner'] as String,
    );

Map<String, dynamic> _$ShovePieceDtoToJson(ShovePieceDto instance) =>
    <String, dynamic>{
      'pieceType': instance.pieceType,
      'texture': instance.texture,
      'isIncapacitated': instance.isIncapacitated,
      'owner': instance.owner,
    };
