// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shove_square_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShoveSquareDto _$ShoveSquareDtoFromJson(Map<String, dynamic> json) =>
    ShoveSquareDto(
      json['x'] as int,
      json['y'] as int,
      json['pieceId'] as String?,
    );

Map<String, dynamic> _$ShoveSquareDtoToJson(ShoveSquareDto instance) =>
    <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
      'pieceId': instance.pieceId,
    };
