// SPSA tuning of the min-max evaluation weights, run with:
//   dart run tool/min_max_spsa.dart [--iterations=100] [--pairs=10] [--nodes=20000] [--jobs=8] [--seed=0]
//
// Every iteration perturbs all weights at once by +/- a step, plays the two
// perturbed configs against each other and moves the weights towards the winner.
import 'dart:io';
import 'dart:math';

import 'package:shove/ai/min_max/min_max_config.dart';

import 'min_max_match.dart';

typedef _Param = ({
  String name,
  int Function(MinMaxConfig) read,
  MinMaxConfig Function(MinMaxConfig, int) write,
});

List<int> _with(List<int> list, int index, int value) =>
    [...list]..[index] = value;

final _params = <_Param>[
  (
    name: 'shoverValue',
    read: (c) => c.shoverValue,
    write: (c, v) => c.copyWith(shoverValue: v),
  ),
  (
    name: 'throwerValue',
    read: (c) => c.throwerValue,
    write: (c, v) => c.copyWith(throwerValue: v),
  ),
  (
    name: 'blockerValue',
    read: (c) => c.blockerValue,
    write: (c, v) => c.copyWith(blockerValue: v),
  ),
  (
    name: 'leaperValue',
    read: (c) => c.leaperValue,
    write: (c, v) => c.copyWith(leaperValue: v),
  ),
  (
    name: 'chargerValue',
    read: (c) => c.chargerValue,
    write: (c, v) => c.copyWith(chargerValue: v),
  ),
  (
    name: 'hookValue',
    read: (c) => c.hookValue,
    write: (c, v) => c.copyWith(hookValue: v),
  ),
  for (var i = 1; i <= 5; i++)
    (
      name: 'shoverAdvance[$i]',
      read: (c) => c.shoverAdvance[i],
      write: (c, v) => c.copyWith(shoverAdvance: _with(c.shoverAdvance, i, v)),
    ),
  for (var i = 1; i <= 6; i++)
    (
      name: 'passedShoverBonus[$i]',
      read: (c) => c.passedShoverBonus[i],
      write: (c, v) =>
          c.copyWith(passedShoverBonus: _with(c.passedShoverBonus, i, v)),
    ),
  for (var i = 1; i <= 3; i++)
    (
      name: 'shoverScarcity[$i]',
      read: (c) => c.shoverScarcity[i],
      write: (c, v) =>
          c.copyWith(shoverScarcity: _with(c.shoverScarcity, i, v)),
    ),
  (
    name: 'incapacitatedPenalty',
    read: (c) => c.incapacitatedPenalty,
    write: (c, v) => c.copyWith(incapacitatedPenalty: v),
  ),
  (
    name: 'throwerReach',
    read: (c) => c.throwerReach,
    write: (c, v) => c.copyWith(throwerReach: v),
  ),
  (
    name: 'leaperReach',
    read: (c) => c.leaperReach,
    write: (c, v) => c.copyWith(leaperReach: v),
  ),
  (
    name: 'blockerGuardBonus',
    read: (c) => c.blockerGuardBonus,
    write: (c, v) => c.copyWith(blockerGuardBonus: v),
  ),
  (
    name: 'shoverSupportBonus',
    read: (c) => c.shoverSupportBonus,
    write: (c, v) => c.copyWith(shoverSupportBonus: v),
  ),
  (
    name: 'springboardBonus',
    read: (c) => c.springboardBonus,
    write: (c, v) => c.copyWith(springboardBonus: v),
  ),
  (name: 'tempo', read: (c) => c.tempo, write: (c, v) => c.copyWith(tempo: v)),
];

MinMaxConfig _toConfig(MinMaxConfig base, List<double> theta) {
  var config = base;
  for (var i = 0; i < _params.length; i++) {
    config = _params[i].write(config, theta[i].round());
  }
  return config;
}

Future<void> main(List<String> args) async {
  final options = {
    for (final arg in args.where((a) => a.startsWith('--')))
      arg.substring(2).split('=')[0]: arg.split('=').skip(1).join('='),
  };
  final iterations = int.parse(options['iterations'] ?? '100');
  final pairs = int.parse(options['pairs'] ?? '10');
  final nodes = int.parse(options['nodes'] ?? '20000');
  final seedBase = int.parse(options['seed'] ?? '0');
  final jobs = int.parse(
    options['jobs'] ?? '${max(1, Platform.numberOfProcessors - 1)}',
  );

  // Fixed to the current weights, so the match is the tuned config vs the start
  final start = const MinMaxConfig();
  final theta = [for (final p in _params) p.read(start).toDouble()];
  // How far one step may move a weight: a tenth of its size, at least 2
  final stepSize = [for (final t in theta) max(2.0, t.abs() / 10)];
  final random = Random(seedBase);
  final clock = Stopwatch()..start();

  stdout.writeln(
    '${_params.length} weights, $iterations iterations, ${pairs * 2} games '
    'each, $nodes nodes per move, $jobs parallel games',
  );

  for (var k = 1; k <= iterations; k++) {
    // Steps shrink as the tuning settles
    final decay = pow(k, 0.3).toDouble();
    final signs = [for (final _ in theta) random.nextBool() ? 1 : -1];
    final plus = <double>[];
    final minus = <double>[];
    for (var i = 0; i < theta.length; i++) {
      final step = stepSize[i] / decay;
      plus.add(theta[i] + signs[i] * step);
      minus.add(theta[i] - signs[i] * step);
    }

    final outcomes = await runInParallel(
      matchGames(
        challenger: _toConfig(start, plus),
        champion: _toConfig(start, minus),
        pairs: pairs,
        nodes: nodes,
        seedBase: seedBase + k * 1000,
      ),
      jobs,
    );
    // -1 (minus won every game) to 1 (plus won every game)
    final result = outcomes.fold(0, (a, b) => a + b) / outcomes.length;

    for (var i = 0; i < theta.length; i++) {
      theta[i] += result * signs[i] * stepSize[i] / decay;
    }
    stdout.writeln(
      'Iteration $k: plus scored ${(50 + 50 * result).toStringAsFixed(0)}% '
      '(${clock.elapsed.inMinutes} min)',
    );
    if (k % 10 == 0 || k == iterations) _printWeights(theta);
  }
}

void _printWeights(List<double> theta) {
  final tuned = _toConfig(const MinMaxConfig(), theta);
  stdout.writeln('Current weights:\n$tuned');
}
