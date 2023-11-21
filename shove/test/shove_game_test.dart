import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_player.dart';
import 'package:shove/game_objects/shove_square.dart';

void main() {
  group('Validation tests', () {
    test('Move should pass validation given a valid move', () {
      final sut = ShoveGame(ShovePlayer("test1", true), ShovePlayer("test2", false));

      var oldSquare = ShoveSquare(
          1, 2, ShovePiece(PieceType.shover, Image.network("placeholder")));
      var newSquare = ShoveSquare(
          2, 2, ShovePiece(PieceType.shover, Image.network("placeholder")));

      var result = sut.validateMove(oldSquare, newSquare);

      expect(result, true);
    });

    test(
        'Move should fail validation given a piece alredy exists on the new square',
        () {
      final sut = ShoveGame(ShovePlayer("test1", true), ShovePlayer("test2", false));

      sut.getSquareByXY(2, 2).piece =
          ShovePiece(PieceType.shover, Image.network("placeholder"), sut.player1);

      var oldSquare = ShoveSquare(
          1, 2, ShovePiece(PieceType.shover, Image.network("placeholder"), sut.player1));
      var newSquare = ShoveSquare(
          2, 2, ShovePiece(PieceType.shover, Image.network("placeholder")));

      var result = sut.validateMove(oldSquare, newSquare);

      expect(result, false);
    });

    test('Move should fail validation given it is out ouf bounds', () {
      final sut = ShoveGame(ShovePlayer("test1", true), ShovePlayer("test2", false));

      var oldSquare = ShoveSquare(
          7, 2, ShovePiece(PieceType.shover, Image.network("placeholder")));
      var newSquare = ShoveSquare(
          8, 2, ShovePiece(PieceType.shover, Image.network("placeholder")));

      var result = sut.validateMove(oldSquare, newSquare);

      expect(result, false);
    });

    test('Move should fail validation given piece is missing', () {
      final sut = ShoveGame();

      var oldSquare = ShoveSquare(1, 2, null);
      var newSquare = ShoveSquare(
          2, 2, ShovePiece(PieceType.shover, Image.network("placeholder")));

      var result = sut.validateMove(oldSquare, newSquare);

      expect(result, false);
    });

    test('Move should fail validation given it moves too many squares', () {
      final sut = ShoveGame();

      var oldSquare = ShoveSquare(
          1, 2, ShovePiece(PieceType.shover, Image.network("placeholder")));
      var newSquare = ShoveSquare(
          3, 2, ShovePiece(PieceType.shover, Image.network("placeholder")));

      var result = sut.validateMove(oldSquare, newSquare);

      expect(result, false);
    });
  });
}
