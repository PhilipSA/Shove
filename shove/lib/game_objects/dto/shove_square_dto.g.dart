// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shove_square_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShoveSquareDto _$ShoveSquareDtoFromJson(Map<String, dynamic> json) =>
    ShoveSquareDto(
      json['x'] as int,
      json['y'] as int,
      json['piece'] == null
          ? null
          : ShovePieceDto.fromJson(json['piece'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ShoveSquareDtoToJson(ShoveSquareDto instance) =>
    <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
      'piece': instance.piece,
    };
