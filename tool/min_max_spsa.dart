// SPSA tuning of the min-max evaluation weights, run with:
//   dart run tool/min_max_spsa.dart [--iterations=100] [--pairs=10] [--nodes=20000] [--jobs=8] [--seed=0]
//
// Every iteration perturbs all weights at once by +/- a step, plays the two
// perturbed configs against each other and moves the weights towards the winner.
import 'dart:io';
import 'dart:math';

import 'package:shove/ai/min_max/min_max_config.dart';

import 'min_max_match.dart';
import 'min_max_params.dart';

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
  final theta = [for (final p in tuneParams) p.read(start).toDouble()];
  // How far one step may move a weight: a tenth of its size, at least 2
  final stepSize = [for (final t in theta) max(2.0, t.abs() / 10)];
  final random = Random(seedBase);
  final clock = Stopwatch()..start();

  stdout.writeln(
    '${tuneParams.length} weights, $iterations iterations, ${pairs * 2} games '
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
        challenger: configFromTheta(start, plus),
        champion: configFromTheta(start, minus),
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
  final tuned = configFromTheta(const MinMaxConfig(), theta);
  stdout.writeln('Current weights:\n$tuned');
}
