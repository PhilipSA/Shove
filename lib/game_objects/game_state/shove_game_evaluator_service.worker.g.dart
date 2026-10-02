// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'shove_game_evaluator_service.dart';

// **************************************************************************
// Generator: WorkerGenerator 9.3.2 (Squadron 7.4.4)
// **************************************************************************

// dart format width=80
/// Command ids used in operations map
const int _$evaluateGameStateId = 1;
const int _$findBestMoveId = 2;

/// WorkerService operations for ShoveGameEvaluatorService
extension on ShoveGameEvaluatorService {
  OperationsMap _$getOperations() => OperationsMap({
    _$evaluateGameStateId: ($req) async {
      final double $res;
      try {
        final $dsr = _$Deser(contextAware: false);
        $res = await evaluateGameState(
          $dsr.$0($req.args[0]),
          $dsr.$0($req.args[1]),
        );
      } finally {}
      return $res;
    },
    _$findBestMoveId: ($req) async {
      final String? $res;
      try {
        final $dsr = _$Deser(contextAware: false);
        $res = await findBestMove($dsr.$0($req.args[0]));
      } finally {}
      return $res;
    },
  });
}

/// Invoker for ShoveGameEvaluatorService, implements the public interface to invoke the
/// remote service.
base mixin _$ShoveGameEvaluatorService$Invoker on Invoker
    implements ShoveGameEvaluatorService {
  @override
  Future<double> evaluateGameState(
    String shoveGameJson,
    String shovePlayerJson,
  ) async {
    final dynamic $res = await send(
      _$evaluateGameStateId,
      args: [shoveGameJson, shovePlayerJson],
    );
    try {
      final $dsr = _$Deser(contextAware: false);
      return $dsr.$1($res);
    } finally {}
  }

  @override
  Future<String?> findBestMove(String shoveGameJson) async {
    final dynamic $res = await send(_$findBestMoveId, args: [shoveGameJson]);
    try {
      final $dsr = _$Deser(contextAware: false);
      return $dsr.$2($res);
    } finally {}
  }
}

/// Facade for ShoveGameEvaluatorService, implements other details of the service unrelated to
/// invoking the remote service.
base mixin _$ShoveGameEvaluatorService$Facade
    implements ShoveGameEvaluatorService {}

/// WorkerClient for ShoveGameEvaluatorService
final class $ShoveGameEvaluatorService$Client extends WorkerClient
    with _$ShoveGameEvaluatorService$Invoker, _$ShoveGameEvaluatorService$Facade
    implements ShoveGameEvaluatorService {
  $ShoveGameEvaluatorService$Client(PlatformChannel channelInfo)
    : super(Channel.deserialize(channelInfo)!);
}

/// Local worker extension for ShoveGameEvaluatorService
extension $ShoveGameEvaluatorServiceLocalWorkerExt
    on ShoveGameEvaluatorService {
  // Get a fresh local worker instance.
  LocalWorker<ShoveGameEvaluatorService> getLocalWorker([
    ExceptionManager? exceptionManager,
  ]) => LocalWorker.create(this, _$getOperations(), exceptionManager);
}

/// WorkerService class for ShoveGameEvaluatorService
base class _$ShoveGameEvaluatorService$WorkerService
    extends ShoveGameEvaluatorService
    implements WorkerService {
  _$ShoveGameEvaluatorService$WorkerService() : super();

  @override
  OperationsMap get operations => _$getOperations();
}

/// Service initializer for ShoveGameEvaluatorService
WorkerService $ShoveGameEvaluatorServiceInitializer(WorkerRequest $req) =>
    _$ShoveGameEvaluatorService$WorkerService();

/// Worker for ShoveGameEvaluatorService
base class ShoveGameEvaluatorServiceWorker extends Worker
    with _$ShoveGameEvaluatorService$Invoker, _$ShoveGameEvaluatorService$Facade
    implements ShoveGameEvaluatorService {
  // ignore: use_super_parameters
  ShoveGameEvaluatorServiceWorker({
    PlatformThreadHook? threadHook,
    ExceptionManager? exceptionManager,
  }) : super(
         $ShoveGameEvaluatorServiceActivator(Squadron.platformType),
         threadHook: threadHook,
         exceptionManager: exceptionManager,
       );

  // ignore: use_super_parameters
  ShoveGameEvaluatorServiceWorker.vm({
    PlatformThreadHook? threadHook,
    ExceptionManager? exceptionManager,
  }) : super(
         $ShoveGameEvaluatorServiceActivator(SquadronPlatformType.vm),
         threadHook: threadHook,
         exceptionManager: exceptionManager,
       );

  // ignore: use_super_parameters
  ShoveGameEvaluatorServiceWorker.js({
    PlatformThreadHook? threadHook,
    ExceptionManager? exceptionManager,
  }) : super(
         $ShoveGameEvaluatorServiceActivator(SquadronPlatformType.js),
         threadHook: threadHook,
         exceptionManager: exceptionManager,
       );

  @override
  List? getStartArgs() => null;
}

/// Worker pool for ShoveGameEvaluatorService
base class ShoveGameEvaluatorServiceWorkerPool
    extends WorkerPool<ShoveGameEvaluatorServiceWorker>
    with _$ShoveGameEvaluatorService$Facade
    implements ShoveGameEvaluatorService {
  // ignore: use_super_parameters
  ShoveGameEvaluatorServiceWorkerPool({
    PlatformThreadHook? threadHook,
    ExceptionManager? exceptionManager,
    ConcurrencySettings? concurrencySettings,
  }) : super(
         (ExceptionManager exceptionManager) => ShoveGameEvaluatorServiceWorker(
           threadHook: threadHook,
           exceptionManager: exceptionManager,
         ),
         concurrencySettings: concurrencySettings,
         exceptionManager: exceptionManager,
       );

  // ignore: use_super_parameters
  ShoveGameEvaluatorServiceWorkerPool.vm({
    PlatformThreadHook? threadHook,
    ExceptionManager? exceptionManager,
    ConcurrencySettings? concurrencySettings,
  }) : super(
         (ExceptionManager exceptionManager) =>
             ShoveGameEvaluatorServiceWorker.vm(
               threadHook: threadHook,
               exceptionManager: exceptionManager,
             ),
         concurrencySettings: concurrencySettings,
         exceptionManager: exceptionManager,
       );

  // ignore: use_super_parameters
  ShoveGameEvaluatorServiceWorkerPool.js({
    PlatformThreadHook? threadHook,
    ExceptionManager? exceptionManager,
    ConcurrencySettings? concurrencySettings,
  }) : super(
         (ExceptionManager exceptionManager) =>
             ShoveGameEvaluatorServiceWorker.js(
               threadHook: threadHook,
               exceptionManager: exceptionManager,
             ),
         concurrencySettings: concurrencySettings,
         exceptionManager: exceptionManager,
       );

  @override
  Future<double> evaluateGameState(
    String shoveGameJson,
    String shovePlayerJson,
  ) => execute((w) => w.evaluateGameState(shoveGameJson, shovePlayerJson));

  @override
  Future<String?> findBestMove(String shoveGameJson) =>
      execute((w) => w.findBestMove(shoveGameJson));
}

final class _$Deser extends MarshalingContext {
  _$Deser({super.contextAware});
  late final $0 = value<String>();
  late final $1 = value<double>();
  late final $2 = Converter.allowNull($0);
}
