import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shove/ai/alpha_zero/alpha_zero_ai.dart';
import 'package:shove/ai/alpha_zero/alpha_zero_model.dart';
import 'package:shove/ai/alpha_zero/alpha_zero_protocol.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
import 'package:shove/game_objects/dto/shove_player_dto.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';
import 'package:shove/game_objects/shove_player.dart';

import 'alpha_zero_helpers.dart';
import 'test_helpers.dart';

Map<String, dynamic> requestFor(ShoveGame game, {int thinkMs = 200}) =>
    jsonDecode(
      jsonEncode(
        alphaZeroRequest(
          game,
          thinkTime: Duration(milliseconds: thinkMs),
          simulations: AlphaZeroAi.timedSimulationCap,
          seed: 7,
        ),
      ),
    ) as Map<String, dynamic>;

/// Everything the network and rules can see: board incl. stuns, turn, history, result.
String stateOf(ShoveGame game) =>
    '${azBoard(game)}|${game.currentPlayersTurn.isWhite}|'
    '${[for (final move in game.allMadeMoves) azMove(move)]}|'
    '${game.isGameOver}|${game.gameOverState?.winner?.isWhite}';

/// A seeded random game from the standard start that favours throws and hook pulls.
/// Returns the game after every ply.
List<ShoveGame> actorHeavyGame(int seed, int plies) {
  final random = Random(seed);
  final game = ShoveGame(ShovePlayer('W', true), ShovePlayer('B', false));
  final positions = <ShoveGame>[];
  for (var ply = 0; ply < plies && !game.isGameOver; ply++) {
    final moves = game.getAllLegalMoves();
    final actors = moves.where((m) => m.throwerSquare != null).toList();
    final pool = actors.isNotEmpty && random.nextBool() ? actors : moves;
    game.move(pool[random.nextInt(pool.length)]);
    positions.add(game.copy());
  }
  return positions;
}

void main() {
  group('model upload validation', () {
    test('accepts both architectures and describes them', () {
      final local = AlphaZeroModel.parse('a.json', syntheticWeights());
      final legacy = AlphaZeroModel.parse(
        'b.json',
        syntheticWeights(localPolicy: false),
      );
      expect(local.network.localPolicy, isTrue);
      expect(local.description, contains('local-policy residual head'));
      expect(local.description, contains('a.json'));
      expect(local.description, contains('checkpoint synthetic-c'));
      expect(legacy.description, contains('legacy policy head'));
    });

    test('rejects other rules, formats, shapes and non-JSON readably', () {
      void rejects(String text, String message) => expect(
        () => AlphaZeroModel.parse('m.json', text),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
      );

      rejects(syntheticWeights(rulesHash: 'f' * 64), 'different rules');
      rejects('not json', 'not a usable AlphaZero model');
      rejects('[]', 'not a usable AlphaZero model');
      final weights = jsonDecode(syntheticWeights()) as Map<String, dynamic>;
      rejects(jsonEncode({...weights, 'format': 'other'}), 'Unsupported');
      (weights['tensors'] as Map)['value.bias'] = {
        'shape': [2],
        'data': [0, 0],
      };
      rejects(jsonEncode(weights), 'Wrong tensor shape: value.bias');
    });

    test('the exported network matches PyTorch reference outputs', () {
      final file = fixture('reference.json');
      if (!file.existsSync()) {
        markTestSkipped('copy dart-001 reference.json into $fixtures');
        return;
      }
      final network = testModel().network;
      for (final reference in jsonDecode(file.readAsStringSync()) as List) {
        final observation = reference['observation'] as Map;
        final prediction = network.predict(
          List<int>.from(observation['board'] as List),
          observation['turn'] as int,
          [
            for (final move in observation['moves'] as List)
              List<int>.from(move as List),
          ],
        );
        final logits = reference['logits'] as List;
        for (var i = 0; i < logits.length; i++) {
          expect(prediction.logits[i], closeTo(logits[i] as num, 1e-4));
        }
        expect(prediction.value, closeTo(reference['value'] as num, 1e-4));
      }
    });
  });

  group('history replay', () {
    test('reproduces actor moves, stuns and both turns exactly', () {
      var actorMoves = 0, stunnedPositions = 0, blackToMove = 0;
      for (final seed in [1, 2, 3]) {
        for (final game in actorHeavyGame(seed, 120)) {
          if (game.isGameOver) continue;
          final replayed = replayAlphaZeroHistory(requestFor(game));
          expect(stateOf(replayed), stateOf(game));
          expect(replayed.positionKey, game.positionKey);
          if (game.allMadeMoves.last.throwerSquare != null) actorMoves++;
          if (azBoard(game).any((code) => code > 12)) stunnedPositions++;
          if (!game.currentPlayersTurn.isWhite) blackToMove++;
        }
      }
      expect(actorMoves, greaterThan(0), reason: 'covers throws/hook pulls');
      expect(stunnedPositions, greaterThan(0), reason: 'covers stuns');
      expect(blackToMove, greaterThan(0), reason: 'covers both turns');
    });

    test('keeps repetition history: the replay ends in the same draw', () {
      // One piece per side shuffles back and forth until one move before a draw.
      final game = ShoveGame(ShovePlayer('W', true), ShovePlayer('B', false));
      String key(ShoveGameMove move) => '${azMove(move)}';
      ShoveGameMove? find(ShoveGame on, String tuple) =>
          on.getAllLegalMoves().where((m) => key(m) == tuple).firstOrNull;
      String reverse(String tuple) {
        final [from, to, _] = jsonDecode(tuple) as List;
        return '[$to, $from, 64]';
      }

      // First white and black non-actor moves that can both be taken back.
      late List<String> cycle;
      search:
      for (final white in game.getAllLegalMoves()) {
        if (white.throwerSquare != null) continue;
        final afterWhite = game.copy()..move(white);
        for (final black in afterWhite.getAllLegalMoves()) {
          if (black.throwerSquare != null) continue;
          final probe = afterWhite.copy()..move(black);
          final back = find(probe, reverse(key(white)));
          if (back == null) continue;
          probe.move(back);
          if (find(probe, reverse(key(black))) == null) continue;
          cycle = [
            key(white),
            key(black),
            reverse(key(white)),
            reverse(key(black)),
          ];
          break search;
        }
      }

      for (var ply = 0; ply < 40; ply++) {
        final next = cycle[ply % 4];
        final copy = game.copy()..move(find(game, next)!);
        if (copy.isGameOver) {
          expect(copy.gameOverReason, GameOverReason.repetition);
          final replayed = replayAlphaZeroHistory(requestFor(game));
          replayed.move(find(replayed, next)!);
          expect(replayed.gameOverReason, GameOverReason.repetition);
          return;
        }
        game.move(find(game, next)!);
      }
      fail('no repetition draw within 40 plies');
    });

    test('rejects custom starts and histories that do not match the board', () {
      final custom = repetitionGame(
        ShovePlayer('W', true),
        ShovePlayer('B', false),
      );
      expect(
        () => replayAlphaZeroHistory(requestFor(custom)),
        throwsA(isA<FormatException>()),
      );

      final game = actorHeavyGame(4, 6).last;
      final tamperedBoard = requestFor(game);
      (tamperedBoard['board'] as List)[0] = 0;
      expect(
        () => replayAlphaZeroHistory(tamperedBoard),
        throwsA(isA<FormatException>()),
      );
      final illegal = requestFor(game);
      (illegal['moves'] as List)[0] = [0, 63, 64];
      expect(
        () => replayAlphaZeroHistory(illegal),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Move 1'),
          ),
        ),
      );
    });
  });

  group('AlphaZeroAi', () {
    final model = testModel();

    test('in-process search plays legal moves for both colours without '
        'mutating the game', () async {
      for (final game in actorHeavyGame(5, 9).skip(6)) {
        final mover = game.currentPlayersTurn;
        final ai = AlphaZeroAi(
          mover.playerName,
          mover.isWhite,
          network: model.network,
          simulations: 32,
        );
        final before = stateOf(game);
        final move = await ai.makeMove(game);
        expect(stateOf(game), before);
        expect(
          game.getAllLegalMoves().map((m) => '${azMove(m)}'),
          contains('${azMove(move)}'),
        );
        expect(ai.lastSearch!.simulations, 32);
      }
    });

    test('the worker request answers within the think time', () async {
      final game = actorHeavyGame(6, 7).last;
      final clock = Stopwatch()..start();
      final result = await runAlphaZeroRequest(
        model.network,
        requestFor(game, thinkMs: 300),
      );
      expect(clock.elapsedMilliseconds, lessThan(2000));
      expect(result['simulations'], greaterThan(0));
      expect(
        game.getAllLegalMoves().map((m) => '${azMove(m)}'),
        contains('${result['move']}'),
      );
    });

    test('the model player searches off the caller\'s game and returns its '
        'own legal move', () async {
      final game = actorHeavyGame(7, 8).last;
      final mover = game.currentPlayersTurn;
      final ai = AlphaZeroAi.withModel(
        mover.playerName,
        mover.isWhite,
        model,
        thinkTime: const Duration(milliseconds: 300),
      );
      final before = stateOf(game);
      final move = await ai.makeMove(game);
      expect(stateOf(game), before);
      expect(game.getAllLegalMoves(), contains(move));
      expect(
        identical(
          move.oldSquare,
          game.getSquareByXY(move.oldSquare.x, move.oldSquare.y),
        ),
        isTrue,
      );
      expect(ai.lastSearch!.simulations, greaterThan(0));
      ai.dispose();
    });

    test('refuses to search out of turn', () {
      final game = ShoveGame(ShovePlayer('W', true), ShovePlayer('B', false));
      final ai = AlphaZeroAi.withModel('B', false, syntheticModel);
      expect(() => ai.makeMove(game), throwsStateError);
    });

    test(
      'stopping a search for its game fails it; other games are ignored',
      () async {
        final ai = AlphaZeroAi.withModel(
          'W',
          true,
          syntheticModel,
          thinkTime: const Duration(seconds: 5),
        );
        final game = ShoveGame(ai, ShovePlayer('B', false));
        final thinking = ai.makeMove(game);
        ai.stopThinking(ShoveGame(ai, ShovePlayer('B', false)));
        ai.stopThinking(game);
        await expectLater(thinking, throwsStateError);
      },
    );

    test('DTOs carry only the name: weights never serialize and AlphaZero '
        'falls back to a plain player', () {
      final ai = AlphaZeroAi.withModel('Zero', false, syntheticModel);
      final game = ShoveGame(ShovePlayer('W', true), ai);
      final json = jsonEncode(ShoveGameStateDto.fromGame(game).toJson());
      expect(json, isNot(contains('tensors')));
      expect(json.length, lessThan(20000));
      final dto = ShovePlayerDto.fromPlayer(ai);
      expect(dto.type, 'AlphaZeroAi');
      final restored = IPlayer.fromDto(dto);
      expect(restored, isA<ShovePlayer>());
      expect(restored, ai);
      expect(identical(game.snapshot().player2, ai), isTrue);
    });
  });
}
