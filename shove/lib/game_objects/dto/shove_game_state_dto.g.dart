// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shove_game_state_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShoveGameStateDto _$ShoveGameStateDtoFromJson(Map<String, dynamic> json) =>
    ShoveGameStateDto(
      (json['board'] as List<dynamic>)
          .map((e) => (e as List<dynamic>)
              .map((e) => ShoveSquareDto.fromJson(e as Map<String, dynamic>))
              .toList())
          .toList(),
      (json['pieces'] as List<dynamic>)
          .map((e) => ShovePieceDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      (json['allMadeMoves'] as List<dynamic>)
          .map((e) => ShoveGameMoveDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      IPlayer.fromJson(json['player1'] as Map<String, dynamic>),
      IPlayer.fromJson(json['player2'] as Map<String, dynamic>),
      IPlayer.fromJson(json['currentPlayersTurn'] as Map<String, dynamic>),
      _$recordConvertNullable(
        json['gameOverState'],
        ($jsonValue) => (
          isOver: $jsonValue['isOver'] as bool,
          winner: $jsonValue['winner'] == null
              ? null
              : IPlayer.fromJson($jsonValue['winner'] as Map<String, dynamic>),
        ),
      ),
    );

Map<String, dynamic> _$ShoveGameStateDtoToJson(ShoveGameStateDto instance) =>
    <String, dynamic>{
      'board': instance.board,
      'pieces': instance.pieces,
      'allMadeMoves': instance.allMadeMoves,
      'player1': instance.player1,
      'player2': instance.player2,
      'currentPlayersTurn': instance.currentPlayersTurn,
      'gameOverState': instance.gameOverState == null
          ? null
          : {
              'isOver': instance.gameOverState!.isOver,
              'winner': instance.gameOverState!.winner,
            },
    };

$Rec? _$recordConvertNullable<$Rec>(
  Object? value,
  $Rec Function(Map) convert,
) =>
    value == null ? null : convert(value as Map<String, dynamic>);
