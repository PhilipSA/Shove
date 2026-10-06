// Knockout tournament between min-max variants, run with:
//   dart run tool/min_max_tournament.dart [--pairs=20] [--nodes=20000] [--jobs=8] [--seed=0]
//
// Each round the champion plays a challenger that is the champion plus a few
// tweaks. Every opening is played twice with the colours swapped. Moves are
// limited by a node budget (not time), so games are reproducible and can run in
// parallel. The challenger replaces the champion only if it scores above 50%.
import 'dart:io';
import 'dart:math';

import 'package:shove/ai/min_max/min_max_config.dart';

import 'min_max_match.dart';

typedef _Tweak = ({String name, MinMaxConfig Function(MinMaxConfig) apply});

final _tweaks = <_Tweak>[
  (
    name: 'futility pruning, margin 200 per depth',
    apply: (c) => c.copyWith(futilityMargin: 200),
  ),
  (
    name: 'null move from depth 3',
    apply: (c) => c.copyWith(nullMoveMinDepth: 3),
  ),
];

Future<void> main(List<String> args) async {
  final options = {
    for (final arg in args.where((a) => a.startsWith('--')))
      arg.substring(2).split('=')[0]: arg.split('=').skip(1).join('='),
  };
  final pairs = int.parse(options['pairs'] ?? '20');
  final nodes = int.parse(options['nodes'] ?? '20000');
  final seedBase = int.parse(options['seed'] ?? '0');
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

    final outcomes = await runInParallel(
      matchGames(
        challenger: challenger,
        champion: champion,
        pairs: pairs,
        nodes: nodes,
        seedBase: seedBase + round * 100000,
      ),
      jobs,
    );

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
