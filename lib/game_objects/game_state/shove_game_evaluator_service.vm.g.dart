// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: WorkerGenerator 9.3.2 (Squadron 7.4.4)
// **************************************************************************

import 'package:squadron/squadron.dart';

import 'shove_game_evaluator_service.dart';

void _start$ShoveGameEvaluatorService(WorkerRequest command) {
  /// VM entry point for ShoveGameEvaluatorService
  run($ShoveGameEvaluatorServiceInitializer, command);
}

EntryPoint $getShoveGameEvaluatorServiceActivator(
  SquadronPlatformType platform,
) {
  if (platform.isVm) {
    return _start$ShoveGameEvaluatorService;
  } else {
    throw UnsupportedError('${platform.label} not supported.');
  }
}
