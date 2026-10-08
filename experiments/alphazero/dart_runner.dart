// JSON-lines native runner. The network/player files themselves do not import dart:io.
import 'dart:convert';
import 'dart:io';

import 'dart_network.dart';
import 'dart_player.dart';
import 'engine.dart' as bridge;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart_runner <weights.json> [simulations=256] [milliseconds]',
    );
    exitCode = 2;
    return;
  }
  final network = DartPolicyValue.fromJson(await File(args[0]).readAsString());
  final simulations = args.length > 1 ? int.parse(args[1]) : 256;
  final budget = args.length > 2
      ? Duration(milliseconds: int.parse(args[2]))
      : null;
  AlphaZeroAi player(bool white) => AlphaZeroAi(
    'AlphaZero',
    white,
    network: network,
    simulations: simulations,
    thinkTime: budget,
  );
  var players = [player(true), player(false)];
  var game = bridge.newGame('initial');
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    try {
      final request = jsonDecode(line) as Map<String, dynamic>;
      Object response;
      switch (request['op']) {
        case 'reset':
          game = bridge.newGame(
            request['fixture'] as String? ?? 'initial',
            request['turn'] as int? ?? 0,
            request['seed'] as int? ?? 0,
          );
          players = [player(true), player(false)];
          response = bridge.observe(game);
        case 'observe':
          response = bridge.observe(game);
        case 'predict':
          final observation = bridge.observe(game);
          final result = network.predict(
            azBoard(game),
            game.currentPlayersTurn.isWhite ? 0 : 1,
            (observation['moves'] as List)
                .map((m) => List<int>.from(m as List))
                .toList(),
          );
          response = {
            'logits': result.logits,
            'policy': result.policy,
            'value': result.value,
          };
        case 'choose':
          final ai = players[game.currentPlayersTurn.isWhite ? 0 : 1];
          final move = await ai.makeMove(game);
          final result = ai.lastSearch!;
          response = {
            'move': azMove(move),
            'search': {
              'simulations': result.simulations,
              'maxDepth': result.maxDepth,
              'cycles': result.cycles,
              'rootValue': result.rootValue,
              'actionVisits': result.actionVisits,
              'policyVisits': result.policyVisits,
              'policySource': result.provenImmediateWin
                  ? 'provenImmediateWin'
                  : 'visits',
            },
          };
        case 'push':
          final wanted = List<int>.from(request['move'] as List);
          if (game.isGameOver) throw StateError('Game is over');
          final move = game.getAllLegalMoves().firstWhere(
            (m) => jsonEncode(azMove(m)) == jsonEncode(wanted),
            orElse: () => throw ArgumentError('Illegal move'),
          );
          game.move(move);
          response = bridge.observe(game);
        case 'pop':
          if (game.allMadeMoves.isEmpty) throw StateError('Nothing to undo');
          game.undoLastMove();
          response = bridge.observe(game);
        default:
          throw ArgumentError(
            'Supported ops: reset, observe, predict, choose, push, pop',
          );
      }
      stdout.writeln(jsonEncode(response));
    } catch (error) {
      stdout.writeln(jsonEncode({'error': '$error'}));
    }
  }
}
