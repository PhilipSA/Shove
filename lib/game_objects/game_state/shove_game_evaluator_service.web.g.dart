// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: WorkerGenerator 9.3.2 (Squadron 7.4.4)
// **************************************************************************

import 'package:squadron/squadron.dart';

import 'shove_game_evaluator_service.dart';

void main() {
  /// Web entry point for ShoveGameEvaluatorService
  run($ShoveGameEvaluatorServiceInitializer);
}

EntryPoint $getShoveGameEvaluatorServiceActivator(
  SquadronPlatformType platform,
) {
  if (platform.isWeb) {
    return Squadron.uri('~/shove_game_evaluator_service.web.g.dart.js');
  } else {
    throw UnsupportedError('${platform.label} not supported.');
  }
}
