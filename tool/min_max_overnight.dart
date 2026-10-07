// Endless min-max tuning, run with:
//   dart run tool/min_max_overnight.dart [--cycle=30] [--pairs=16] [--nodes=40000]
//     [--gatePairs=150] [--gateNodes=100000] [--promote=53] [--jobs=8] [--seed=0] [--resume]
//
// Repeats SPSA (see min_max_spsa.dart) for --cycle iterations, then lets the
// tuned weights play a tournament against the current champion (see
// min_max_tournament.dart). They only replace the champion if they score at least
// --promote percent, so noise in the training games cannot make the champion worse.
// The champion is written to build/min_max_champion.txt after every promotion.
// Stop with Ctrl+C (finishes the running step first, press again to quit at once)
// or by creating the file build/min_max_stop.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shove/ai/min_max/min_max_config.dart';

import 'min_max_match.dart';
import 'min_max_params.dart';

const _championFile = 'build/min_max_champion.txt';
const _stateFile = 'build/min_max_state.json';
const _stopFile = 'build/min_max_stop';

// Keeps the steps from vanishing when the loop runs for thousands of iterations.
const _maxDecayIteration = 200;

Future<void> main(List<String> args) async {
  final options = {
    for (final arg in args.where((a) => a.startsWith('--')))
      arg.substring(2).split('=')[0]: arg.split('=').skip(1).join('='),
  };
  final cycleLength = int.parse(options['cycle'] ?? '30');
  final pairs = int.parse(options['pairs'] ?? '16');
  final nodes = int.parse(options['nodes'] ?? '40000');
  final gatePairs = int.parse(options['gatePairs'] ?? '150');
  final gateNodes = int.parse(options['gateNodes'] ?? '100000');
  final promoteAt = double.parse(options['promote'] ?? '53') / 100;
  final seedBase = int.parse(options['seed'] ?? '0');
  final jobs = int.parse(
    options['jobs'] ?? '${max(1, Platform.numberOfProcessors - 1)}',
  );

  Directory('build').createSync();
  final stopFile = File(_stopFile);
  if (stopFile.existsSync()) stopFile.deleteSync();
  var stopRequested = false;
  ProcessSignal.sigint.watch().listen((_) {
    if (stopRequested) exit(0);
    stopRequested = true;
    stdout.writeln(
      'Stopping after the current step (Ctrl+C again to quit now)',
    );
  });
  bool shouldStop() => stopRequested || stopFile.existsSync();

  const start = MinMaxConfig();
  var championTheta = [for (final p in tuneParams) p.read(start).toDouble()];
  var theta = [...championTheta];
  var k = 0;
  var cycle = 0;
  var promotions = 0;

  if (options.containsKey('resume') && File(_stateFile).existsSync()) {
    final state = jsonDecode(File(_stateFile).readAsStringSync()) as Map;
    List<double> read(String key) => [
      for (final v in state[key] as List) (v as num).toDouble(),
    ];
    championTheta = read('championTheta');
    theta = read('theta');
    k = state['k'] as int;
    cycle = state['cycle'] as int;
    promotions = state['promotions'] as int;
    stdout.writeln('Resumed at cycle $cycle, iteration $k');
  }

  void saveState() => File(_stateFile).writeAsStringSync(
    jsonEncode({
      'championTheta': championTheta,
      'theta': theta,
      'k': k,
      'cycle': cycle,
      'promotions': promotions,
    }),
  );

  // How far one step may move a weight: a tenth of its size, at least 2
  final stepSize = [
    for (final p in tuneParams) max(2.0, p.read(start).abs() / 10),
  ];
  final random = Random(seedBase + k);
  final clock = Stopwatch()..start();
  String elapsed() => '${clock.elapsed.inMinutes} min';

  stdout.writeln(
    '${tuneParams.length} weights, cycles of $cycleLength iterations '
    '(${pairs * 2} games at $nodes nodes), gate ${gatePairs * 2} games at '
    '$gateNodes nodes, promote at ${(promoteAt * 100).toStringAsFixed(1)}%, '
    '$jobs parallel games',
  );

  while (!shouldStop()) {
    cycle++;
    for (var i = 0; i < cycleLength && !shouldStop(); i++) {
      k++;
      final decay = pow(min(k, _maxDecayIteration), 0.3).toDouble();
      final signs = [for (final _ in theta) random.nextBool() ? 1 : -1];
      final plus = <double>[];
      final minus = <double>[];
      for (var p = 0; p < theta.length; p++) {
        final step = stepSize[p] / decay;
        plus.add(theta[p] + signs[p] * step);
        minus.add(theta[p] - signs[p] * step);
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
      final result = outcomes.fold(0, (a, b) => a + b) / outcomes.length;
      for (var p = 0; p < theta.length; p++) {
        theta[p] += result * signs[p] * stepSize[p] / decay;
      }
      stdout.writeln(
        'Cycle $cycle, iteration $k: plus scored '
        '${(50 + 50 * result).toStringAsFixed(0)}% (${elapsed()})',
      );
    }
    // An unfinished cycle was not trained enough to be worth a tournament
    if (shouldStop()) break;

    final champion = configFromTheta(start, championTheta);
    final candidate = configFromTheta(start, theta);
    final outcomes = await runInParallel(
      matchGames(
        challenger: candidate,
        champion: champion,
        pairs: gatePairs,
        nodes: gateNodes,
        // Far from the training seeds so the tournament uses fresh openings
        seedBase: seedBase + 5000000 + cycle * 1000,
      ),
      jobs,
    );
    final wins = outcomes.where((o) => o > 0).length;
    final losses = outcomes.where((o) => o < 0).length;
    final draws = outcomes.length - wins - losses;
    final score = (wins + draws / 2) / outcomes.length;
    final promoted = score >= promoteAt;

    stdout.writeln(
      'Cycle $cycle tournament: tuned +$wins =$draws -$losses '
      '(${(100 * score).toStringAsFixed(1)}%) -> '
      '${promoted ? 'NEW CHAMPION' : 'champion stays'} (${elapsed()})',
    );
    if (promoted) {
      promotions++;
      championTheta = [for (final t in theta) t.roundToDouble()];
      File(_championFile).writeAsStringSync(
        '// Promotion $promotions, cycle $cycle, ${DateTime.now()}\n'
        '${configFromTheta(start, championTheta)}\n',
      );
      stdout.writeln('${configFromTheta(start, championTheta)}');
    } else {
      // Training drifted somewhere that is not better, so start over from the champion
      theta = [...championTheta];
    }
    saveState();
  }

  saveState();
  stdout.writeln(
    '\nStopped after $cycle cycles, $promotions promotions, ${elapsed()}.\n'
    'Champion (also in $_championFile):\n${configFromTheta(start, championTheta)}',
  );
  exit(0);
}
