// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shove_game_evaluator_service.dart';

// **************************************************************************
// Generator: WorkerGenerator 2.4.2
// **************************************************************************

/// WorkerService class for ShoveGameEvaluatorService
class _$ShoveGameEvaluatorServiceWorkerService extends ShoveGameEvaluatorService
    implements WorkerService {
  _$ShoveGameEvaluatorServiceWorkerService() : super();

  @override
  Map<int, CommandHandler> get operations => _operations;

  late final Map<int, CommandHandler> _operations =
      Map.unmodifiable(<int, CommandHandler>{
    _$evaluateGameStateId: ($) => evaluateGameState(
        ShoveGameStateDto.fromJson($.args[0]),
        ShovePlayerDto.fromJson($.args[1])),
    _$findBestMoveId: ($) =>
        findBestMove(ShoveGameStateDto.fromJson($.args[0])),
  });

  static const int _$evaluateGameStateId = 1;
  static const int _$findBestMoveId = 2;
}

/// Service initializer for ShoveGameEvaluatorService
WorkerService $ShoveGameEvaluatorServiceInitializer(
        WorkerRequest startRequest) =>
    _$ShoveGameEvaluatorServiceWorkerService();

/// Operations map for ShoveGameEvaluatorService
@Deprecated(
    'squadron_builder now supports "plain old Dart objects" as services. '
    'Services do not need to derive from WorkerService nor do they need to mix in '
    'with \$ShoveGameEvaluatorServiceOperations anymore.')
mixin $ShoveGameEvaluatorServiceOperations on WorkerService {
  @override
  // not needed anymore, generated for compatibility with previous versions of squadron_builder
  Map<int, CommandHandler> get operations => WorkerService.noOperations;
}

/// Worker for ShoveGameEvaluatorService
class ShoveGameEvaluatorServiceWorker extends Worker
    implements ShoveGameEvaluatorService {
  ShoveGameEvaluatorServiceWorker({PlatformWorkerHook? platformWorkerHook})
      : super($ShoveGameEvaluatorServiceActivator,
            platformWorkerHook: platformWorkerHook);

  @override
  Future<double> evaluateGameState(
          ShoveGameStateDto shoveGame, ShovePlayerDto shovePlayerDto) =>
      send(_$ShoveGameEvaluatorServiceWorkerService._$evaluateGameStateId,
          args: [shoveGame.toJson(), shovePlayerDto.toJson()]);

  @override
  Future<(double, ShoveGameMove?)> findBestMove(ShoveGameStateDto shoveGame) =>
      send(_$ShoveGameEvaluatorServiceWorkerService._$findBestMoveId,
          args: [shoveGame.toJson()]);
}

/// Worker pool for ShoveGameEvaluatorService
class ShoveGameEvaluatorServiceWorkerPool
    extends WorkerPool<ShoveGameEvaluatorServiceWorker>
    implements ShoveGameEvaluatorService {
  ShoveGameEvaluatorServiceWorkerPool(
      {ConcurrencySettings? concurrencySettings,
      PlatformWorkerHook? platformWorkerHook})
      : super(
            () => ShoveGameEvaluatorServiceWorker(
                platformWorkerHook: platformWorkerHook),
            concurrencySettings: concurrencySettings);

  @override
  Future<double> evaluateGameState(
          ShoveGameStateDto shoveGame, ShovePlayerDto shovePlayerDto) =>
      execute((w) => w.evaluateGameState(shoveGame, shovePlayerDto));

  @override
  Future<(double, ShoveGameMove?)> findBestMove(ShoveGameStateDto shoveGame) =>
      execute((w) => w.findBestMove(shoveGame));
}
