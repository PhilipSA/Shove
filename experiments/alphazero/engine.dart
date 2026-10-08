import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shove/game_objects/piece_type.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_piece.dart';
import 'package:shove/game_objects/shove_player.dart';

final white = ShovePlayer('white', true);
final black = ShovePlayer('black', false);

ShoveGame newGame(String fixture, [int turn = 0, int seed = 0]) {
  if (turn != 0 && turn != 1) throw ArgumentError('Turn must be 0 or 1');
  if (seed < 0) throw ArgumentError('Seed must be nonnegative');
  if (fixture == 'endgame-tactics') {
    final random = Random(seed);
    final family = seed % 3;
    for (var attempt = 0; attempt < 1024; attempt++) {
      final candidate = newGame('endgame6', turn, random.nextInt(1 << 30));
      final interacts = candidate.getAllLegalMoves().any((move) {
        final actor = move.throwerSquare;
        if (actor != null) {
          final type = candidate.pieceOn(actor)!.pieceType;
          return candidate.pieceOn(move.oldSquare)!.pieceType ==
                  PieceType.shover &&
              type == (family == 0 ? PieceType.hook : PieceType.thrower) &&
              family != 2;
        }
        return family == 2 &&
            candidate.pieceOn(move.oldSquare)!.pieceType == PieceType.charger &&
            candidate.pieceOn(move.newSquare)?.pieceType == PieceType.shover &&
            ((move.oldSquare.x - move.newSquare.x).abs() > 1 ||
                (move.oldSquare.y - move.newSquare.y).abs() > 1);
      });
      if (interacts) return candidate;
    }
    throw StateError('Could not generate tactical position for seed $seed');
  }
  final game = ShoveGame(white, black)
    ..currentPlayersTurn = turn == 0 ? white : black;
  if (fixture == 'initial') return game;
  if (fixture != 'race' &&
      fixture != 'endgame' &&
      fixture != 'endgame6' &&
      fixture != 'endgame8') {
    throw ArgumentError('Unknown fixture: $fixture');
  }
  // Experimental starting positions only; movement and termination remain real rules.
  for (final square in game.squares) {
    square.pieceId = null;
  }
  game.pieces.clear();
  if (fixture.startsWith('endgame')) {
    final random = Random(seed);
    void place(ShovePiece piece, {bool pawn = false}) {
      var square = game.getSquareByXY(
        pawn ? 2 + random.nextInt(4) : random.nextInt(8),
        random.nextInt(8),
      )!;
      while (square.pieceId != null) {
        square = game.getSquareByXY(
          pawn ? 2 + random.nextInt(4) : random.nextInt(8),
          random.nextInt(8),
        )!;
      }
      game.pieces[piece.id] = piece;
      square.pieceId = piece.id;
    }

    for (final owner in [white, black]) {
      place(ShovePiece.shover(owner), pawn: true);
      if (fixture == 'endgame') {
        // Keep the original four-piece distribution exactly reproducible.
        place(
          random.nextBool()
              ? ShovePiece.blocker(owner)
              : ShovePiece.leaper(owner),
        );
      } else {
        if (fixture == 'endgame8') {
          place(ShovePiece.shover(owner), pawn: true);
        }
        final constructors = [
          ShovePiece.blocker,
          ShovePiece.leaper,
          ShovePiece.charger,
          ShovePiece.hook,
          ShovePiece.thrower,
        ]..shuffle(random);
        for (final constructor in constructors.take(2)) {
          place(constructor(owner));
        }
      }
    }
    return game;
  }
  // The race fixture is deliberately trivial: either side can score next turn.
  for (final (x, y, owner) in [(1, 1, white), (6, 6, black)]) {
    final piece = ShovePiece.shover(owner);
    game.pieces[piece.id] = piece;
    game.getSquareByXY(x, y)!.pieceId = piece.id;
  }
  return game;
}

Map<String, Object?> observe(ShoveGame game) {
  final turn = game.currentPlayersTurn == white ? 0 : 1;
  final winner = game.gameOverState?.winner;
  final moves = game.isGameOver ? [] : game.getAllLegalMoves();
  return {
    'board': [
      for (final square in game.squares)
        if (game.pieceOn(square) case final piece?)
          1 +
              piece.pieceType.index +
              (piece.owner == white ? 0 : 6) +
              (piece.isIncapacitated ? 12 : 0)
        else
          0,
    ],
    'turn': turn,
    'moves': [
      for (final move in moves)
        [
          move.oldSquare.x * 8 + move.oldSquare.y,
          move.newSquare.x * 8 + move.newSquare.y,
          move.throwerSquare == null
              ? 64
              : move.throwerSquare!.x * 8 + move.throwerSquare!.y,
        ],
    ],
    'terminal': game.isGameOver,
    'winner': winner == null ? null : (winner == white ? 0 : 1),
    'value': winner == null ? 0 : (winner == game.currentPlayersTurn ? 1 : -1),
    'reason': game.gameOverReason?.name,
    'positionKey': game.positionKey,
    'historyLength': game.allMadeMoves.length,
  };
}

Future<void> main() async {
  var game = newGame('initial');
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    try {
      final request = jsonDecode(line) as Map<String, dynamic>;
      switch (request['op']) {
        case 'reset':
          game = newGame(
            request['fixture'] as String? ?? 'initial',
            request['turn'] as int? ?? 0,
            request['seed'] as int? ?? 0,
          );
        case 'observe':
          break;
        case 'push':
          final index = request['index'];
          final moves = game.getAllLegalMoves();
          if (game.isGameOver ||
              index is! int ||
              index < 0 ||
              index >= moves.length) {
            throw ArgumentError('Invalid legal move index: $index');
          }
          final move = moves[index];
          if (!game.validateMove(move)) {
            throw StateError('Generator returned an illegal move');
          }
          game.move(move);
        case 'pop':
          if (game.allMadeMoves.isEmpty) throw StateError('Nothing to undo');
          game.undoLastMove();
        default:
          throw ArgumentError('Unknown operation');
      }
      stdout.writeln(jsonEncode(observe(game)));
    } catch (error) {
      stdout.writeln(jsonEncode({'error': '$error'}));
    }
  }
}
