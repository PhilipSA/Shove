// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:shove/game_objects/piece_type.dart';
// import 'package:shove/game_objects/shove_piece.dart';
// import 'package:shove/game_objects/shove_game.dart';
// import 'package:shove/game_objects/shove_player.dart';
// import 'package:shove/game_objects/shove_square.dart';

// void main() {
//   group('Validation tests', () {
//     test('Move should pass validation given a valid move', () {
//       var player1 = ShovePlayer("test1", true);
//       var player2 = ShovePlayer("test2", false);
//       final sut = ShoveGame(player1, player2);

//       var sut.getSquareByXY(1, 2);

//       // sut.getSquareByXY(1, 2) = ShoveSquare(
//       //     1,
//       //     2,
//       //     ShovePiece(
//       //         PieceType.shover, SvgPicture.network("placeholder"), player1));
//       // var newSquare = ShoveSquare(2, 2, null);

//       // var result = sut.validateMove(oldSquare, newSquare);

//       // expect(result, true);
//     });

//     test(
//         'Move should fail validation given a piece alredy exists on the new square',
//         () {
//       var player1 = ShovePlayer("test1", true);
//       var player2 = ShovePlayer("test2", false);
//       final sut = ShoveGame(player1, player2);

//       var newPiece = ShovePiece(
//           PieceType.shover, SvgPicture.network("placeholder"), sut.player1);

//           sut.getSquareByXY(x, y)

//       var oldSquare = ShoveSquare(
//           1,
//           2,
//           ShovePiece(PieceType.shover, SvgPicture.network("placeholder"),
//               sut.player1));
//       var newSquare = ShoveSquare(2, 2, newPiece);

//       var result = sut.validateMove(oldSquare, newSquare);

//       expect(result, false);
//     });

//     test('Move should fail validation given it is out ouf bounds', () {
//       var player1 = ShovePlayer("test1", true);
//       var player2 = ShovePlayer("test2", false);
//       final sut = ShoveGame(player1, player2);

//       var oldSquare = ShoveSquare(
//           7,
//           2,
//           ShovePiece(
//               PieceType.shover, SvgPicture.network("placeholder"), player1));
//       var newSquare = ShoveSquare(8, 2, null);

//       var result = sut.validateMove(oldSquare, newSquare);

//       expect(result, false);
//     });

//     test('Move should fail validation given piece is missing', () {
//       var player1 = ShovePlayer("test1", true);
//       var player2 = ShovePlayer("test2", false);
//       final sut = ShoveGame(player1, player2);

//       var oldSquare = ShoveSquare(1, 2, null);
//       var newSquare = ShoveSquare(2, 2, null);

//       var result = sut.validateMove(oldSquare, newSquare);

//       expect(result, false);
//     });

//     test('Move should fail validation given shover moves too many squares', () {
//       var player1 = ShovePlayer("test1", true);
//       var player2 = ShovePlayer("test2", false);
//       final sut = ShoveGame(player1, player2);

//       var oldSquare = ShoveSquare(
//           1,
//           2,
//           ShovePiece(
//               PieceType.shover, SvgPicture.network("placeholder"), player1));
//       var newSquare = ShoveSquare(
//           3,
//           2,
//           ShovePiece(
//               PieceType.shover, SvgPicture.network("placeholder"), player2));

//       var result = sut.validateMove(oldSquare, newSquare);

//       expect(result, false);
//     });
//   });
// }
