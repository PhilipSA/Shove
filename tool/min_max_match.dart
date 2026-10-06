// Shared by the min-max tuning tools: plays reproducible games between configs.
import 'dart:isolate';
import 'dart:math';

import 'package:shove/ai/min_max/min_max_ai.dart';
import 'package:shove/ai/min_max/min_max_config.dart';
import 'package:shove/game_objects/shove_game.dart';

const _openingPlies = 6;
const _maxPlies = 200;

/// Runs [jobs] with at most [concurrency] at a time and returns their results in order.
Future<List<int>> runInParallel(
  List<Future<int> Function()> jobs,
  int concurrency,
) async {
  final results = List<int>.filled(jobs.length, 0);
  var next = 0;

  Future<void> worker() async {
    while (next < jobs.length) {
      final index = next++;
      results[index] = await jobs[index]();
    }
  }

  await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
  return results;
}

/// Games for [pairs] openings, each played twice with the colours swapped.
/// Each result is 1 if the challenger wins, -1 if the champion wins, 0 for a draw.
List<Future<int> Function()> matchGames({
  required MinMaxConfig challenger,
  required MinMaxConfig champion,
  required int pairs,
  required int nodes,
  required int seedBase,
}) => [
  for (var pair = 0; pair < pairs; pair++)
    for (final challengerIsWhite in [true, false])
      () => Isolate.run(
        () => _playGame(
          challenger: challenger,
          champion: champion,
          challengerIsWhite: challengerIsWhite,
          seed: seedBase + pair,
          nodes: nodes,
        ),
      ),
];

Future<int> _playGame({
  required MinMaxConfig challenger,
  required MinMaxConfig champion,
  required bool challengerIsWhite,
  required int seed,
  required int nodes,
}) async {
  MinMaxAi player(String name, bool isWhite, MinMaxConfig config) => MinMaxAi(
    name,
    isWhite,
    thinkTime: const Duration(hours: 1),
    useWorker: false,
    config: config,
    maxNodes: nodes,
  );

  final challengerAi = player('challenger', challengerIsWhite, challenger);
  final championAi = player('champion', !challengerIsWhite, champion);
  final game = challengerIsWhite
      ? ShoveGame(challengerAi, championAi)
      : ShoveGame(championAi, challengerAi);

  // The same seed gives the same opening for both colours
  final random = Random(seed);
  for (var ply = 0; ply < _openingPlies && !game.isGameOver; ply++) {
    final moves = game.getAllLegalMoves();
    game.move(moves[random.nextInt(moves.length)]);
  }

  for (var ply = 0; ply < _maxPlies && !game.isGameOver; ply++) {
    final ai = game.currentPlayersTurn as MinMaxAi;
    game.move(await ai.makeMove(game));
  }

  final winner = game.gameOverState?.winner;
  if (winner == null) return 0;
  return winner == challengerAi ? 1 : -1;
}
