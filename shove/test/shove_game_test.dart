import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shove/piece_type.dart';
import 'package:shove/shove_game.dart';
import 'package:shove/shove_piece.dart';
import 'package:shove/shove_square.dart';

void main() {
  group('Validation tests', () {
    test('Move should pass validation given a valid move', () {
      final sut = ShoveGame();

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
      final sut = ShoveGame();

      sut.getSquareByXY(2, 2).piece =
          ShovePiece(PieceType.shover, Image.network("placeholder"));

      var oldSquare = ShoveSquare(
          1, 2, ShovePiece(PieceType.shover, Image.network("placeholder")));
      var newSquare = ShoveSquare(
          2, 2, ShovePiece(PieceType.shover, Image.network("placeholder")));

      var result = sut.validateMove(oldSquare, newSquare);

      expect(result, false);
    });

    test('Move should fail validation given it is out ouf bounds', () {
      final sut = ShoveGame();

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
