// Run with: dart test_dart_runner.dart <weights.json> <reference.json>
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'dart_network.dart';
import 'dart_player.dart';
import 'engine.dart' as bridge;

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main(List<String> args) async {
  final network = DartPolicyValue.fromJson(File(args[0]).readAsStringSync());
  final cases = jsonDecode(File(args[1]).readAsStringSync()) as List;
  var maxLogitError = 0.0, maxPolicyError = 0.0, maxValueError = 0.0;
  var searches = 0, exactSearches = 0, maxVisitL1 = 0;
  final allowRoundoff = args.length > 2 && args[2] == '--allow-roundoff';
  for (var caseIndex = 0; caseIndex < cases.length; caseIndex++) {
    final test = cases[caseIndex];
    final observation = test['observation'];
    final board = List<int>.from(observation['board']);
    final moves = (observation['moves'] as List)
        .map((m) => List<int>.from(m))
        .toList();
    final prediction = network.predict(board, observation['turn'], moves);
    for (var i = 0; i < moves.length; i++) {
      maxLogitError = max(
        maxLogitError,
        (prediction.logits[i] - test['logits'][i]).abs(),
      );
      maxPolicyError = max(
        maxPolicyError,
        (prediction.policy[i] - test['policy'][i]).abs(),
      );
    }
    maxValueError = max(
      maxValueError,
      (prediction.value - test['value']).abs(),
    );
    if (test['setup'] == null) continue;
    final setup = test['setup'];
    final game = bridge.newGame(setup['fixture'], setup['turn'], setup['seed']);
    for (final move in setup['moves']) {
      game.move(
        game.getAllLegalMoves().firstWhere(
          (m) => jsonEncode(azMove(m)) == jsonEncode(move),
        ),
      );
    }
    final before = jsonEncode(bridge.observe(game));
    check(
      before == jsonEncode(observation),
      'Setup mismatch at case $caseIndex',
    );
    final ai = AlphaZeroAi(
      'AZ',
      game.currentPlayersTurn.isWhite,
      network: network,
      simulations: (test['simulations'] as int?) ?? 32,
    );
    final move = await ai.makeMove(game);
    check(game.validateMove(move), 'Illegal AI move');
    check(
      jsonEncode(bridge.observe(game)) == before,
      'Search modified caller at case $caseIndex',
    );
    final result = ai.lastSearch!;
    check(
      result.simulations == (test['simulations'] ?? 32),
      'Wrong simulation count',
    );
    int distance(List<int> actual, List expected) => List.generate(
      actual.length,
      (i) => (actual[i] - (expected[i] as num).toInt()).abs(),
    ).fold(0, (a, b) => a + b);
    final visitL1 = distance(
      result.actionVisits,
      test['search']['actionVisits'],
    );
    maxVisitL1 = max(maxVisitL1, visitL1);
    if (visitL1 == 0) exactSearches++;
    // Float64 Dart vs Float32 PyTorch can switch a near-tied choice in deep search.
    final tolerance = allowRoundoff && result.simulations >= 1024 ? 2 : 0;
    check(
      visitL1 <= tolerance,
      'Search visits differ at case $caseIndex: L1=$visitL1',
    );
    check(
      distance(result.policyVisits, test['search']['policyVisits']) <=
          tolerance,
      'Target visits differ',
    );
    check(
      result.actionVisits.reduce((a, b) => a + b) == result.simulations,
      'Lost visits',
    );
    check(
      (result.rootValue - test['search']['rootValue']).abs() <
          (tolerance == 0 ? 2e-5 : 1e-4),
      'Root value differs',
    );
    check(result.cycles == test['search']['cycles'], 'Cycle guard differs');
    check(
      result.maxDepth == test['search']['maxDepth'],
      'Search depth differs',
    );
    searches++;
  }
  check(
    maxLogitError < 2e-5 && maxPolicyError < 2e-5 && maxValueError < 2e-5,
    'Inference mismatch: $maxLogitError / $maxPolicyError / $maxValueError',
  );
  final race = bridge.newGame('race');
  final timed = AlphaZeroAi(
    'AZ',
    true,
    network: network,
    simulations: 100000,
    thinkTime: const Duration(microseconds: 1),
  );
  await timed.makeMove(race);
  check(
    timed.lastSearch!.simulations == 1,
    'Expired deadline should stop after one simulation',
  );
  final original = bridge.observe(race);
  final ai = AlphaZeroAi('AZ', true, network: network, simulations: 64);
  final winning = await ai.makeMove(race);
  check(
    ai.lastSearch!.provenImmediateWin,
    'Immediate-win override not exercised',
  );
  check(
    jsonEncode(bridge.observe(race)) == jsonEncode(original),
    'Race search modified game',
  );
  race.move(winning);
  check(
    race.isGameOver && race.gameOverState!.winner!.isWhite,
    'Did not choose proven win',
  );
  try {
    await ai.makeMove(race);
    throw StateError('Terminal search should fail');
  } on StateError catch (error) {
    check(error.message.contains('requires'), 'Unexpected terminal error');
  }
  try {
    DartPolicyValue.fromJson(
      File(args[0]).readAsStringSync(),
      expectedRulesHash: 'wrong',
    );
    throw StateError('Rules mismatch should fail');
  } on FormatException {
    /* expected */
  }
  stdout.writeln(
    jsonEncode({
      'positions': cases.length,
      'validatedSearches': searches,
      'exactSearches': exactSearches,
      'maxVisitL1': maxVisitL1,
      'maxLogitError': maxLogitError,
      'maxPolicyError': maxPolicyError,
      'maxValueError': maxValueError,
      'deadline': 'pass',
      'immediateWin': 'pass',
      'callerUnchanged': 'pass',
    }),
  );
}
