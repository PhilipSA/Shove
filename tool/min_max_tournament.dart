// Knockout tournament between min-max variants, run with:
//   dart run tool/min_max_tournament.dart [--pairs=20] [--nodes=20000] [--jobs=8]
//
// Each round the champion plays a challenger that is the champion plus a few
// tweaks. Every opening is played twice with the colours swapped. Moves are
// limited by a node budget (not time), so games are reproducible and can run in
// parallel. The challenger replaces the champion only if it scores above 50%.
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:shove/ai/min_max_ai.dart';
import 'package:shove/ai/min_max_config.dart';
import 'package:shove/game_objects/shove_game.dart';

const _openingPlies = 6;
const _maxPlies = 200;

typedef _Tweak = ({String name, MinMaxConfig Function(MinMaxConfig) apply});

final _tweaks = <_Tweak>[
  (
    name: 'bigger shover advancement bonuses',
    apply: (c) => c.copyWith(
      shoverAdvance: const [0, 300, 150, 80, 40, 16, 0, 0],
      passedShoverBonus: const [0, 260, 150, 80, 40, 20, 6, 0],
    ),
  ),
  (
    name: 'search: reduce late quiet moves sooner, deeper quiescence',
    apply: (c) =>
        c.copyWith(lateMoveReductionFromIndex: 3, maxQuiescenceDepth: 8),
  ),
  (
    name: 'supported shovers, bigger stun penalty',
    apply: (c) => c.copyWith(shoverSupportBonus: 15, incapacitatedPenalty: 45),
  ),
  (
    name: 'piece values and reach',
    apply: (c) => c.copyWith(
      throwerValue: 330,
      leaperValue: 280,
      blockerValue: 190,
      throwerReach: 20,
      leaperReach: 10,
    ),
  ),
  (
    name: 'edge danger, shover scarcity and tempo',
    apply: (c) => c.copyWith(
      edgeDangerOwnTurnDivisor: 3,
      edgeDangerOpponentTurnDivisor: 1,
      shoverScarcity: const [0, -300, -120, -45],
      tempo: 15,
    ),
  ),
];

Future<void> main(List<String> args) async {
  final options = {
    for (final arg in args.where((a) => a.startsWith('--')))
      arg.substring(2).split('=')[0]: arg.split('=').skip(1).join('='),
  };
  final pairs = int.parse(options['pairs'] ?? '20');
  final nodes = int.parse(options['nodes'] ?? '20000');
  final jobs = int.parse(
    options['jobs'] ?? '${max(1, Platform.numberOfProcessors - 1)}',
  );

  var champion = const MinMaxConfig();
  stdout.writeln(
    '${_tweaks.length} rounds, ${pairs * 2} games each, '
    '$nodes nodes per move, $jobs parallel games',
  );

  for (var round = 0; round < _tweaks.length; round++) {
    final tweak = _tweaks[round];
    final challenger = tweak.apply(champion);
    final clock = Stopwatch()..start();

    final games = [
      for (var pair = 0; pair < pairs; pair++)
        for (final challengerIsWhite in [true, false])
          () => Isolate.run(
            () => _playGame(
              challenger: challenger,
              champion: champion,
              challengerIsWhite: challengerIsWhite,
              seed: round * 100000 + pair,
              nodes: nodes,
            ),
          ),
    ];
    final outcomes = await _runInParallel(games, jobs);

    final wins = outcomes.where((o) => o > 0).length;
    final losses = outcomes.where((o) => o < 0).length;
    final draws = outcomes.length - wins - losses;
    final points = wins + draws / 2;
    final challengerWins = points > outcomes.length / 2;

    stdout.writeln(
      'Round ${round + 1}: ${tweak.name}\n'
      '  challenger +$wins =$draws -$losses '
      '(${(100 * points / outcomes.length).toStringAsFixed(1)}%) '
      'in ${clock.elapsed.inSeconds}s -> '
      '${challengerWins ? 'challenger is the new champion' : 'champion stays'}',
    );
    if (challengerWins) champion = challenger;
  }

  stdout.writeln('\nLast algorithm standing:\n$champion');
}

Future<List<int>> _runInParallel(
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

/// 1 if the challenger wins, -1 if the champion wins, 0 for a draw.
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
