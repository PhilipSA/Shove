import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:shove/ai/alpha_zero/alpha_zero_model.dart';
import 'package:web/web.dart';

/// Script compiled from `alpha_zero_worker_main.dart`; see `tool/build_web_workers.sh`.
const alphaZeroWorkerScript = 'alpha_zero_worker.js';

/// One dedicated web worker per AlphaZero player. It parses the weights once and
/// then answers one search at a time.
class AlphaZeroWorker {
  final Worker _worker;
  Completer<Map<String, dynamic>>? _pending;
  bool _terminated = false;

  AlphaZeroWorker(AlphaZeroModel model)
    : _worker = Worker(alphaZeroWorkerScript.toJS) {
    _worker
      ..onmessage = _onMessage.toJS
      ..onerror = _onError.toJS
      ..onmessageerror = _onError.toJS
      ..postMessage(jsonEncode({'type': 'init', 'weights': model.json}).toJS);
  }

  Future<Map<String, dynamic>> search(
    Map<String, Object?> request, {
    required Duration timeout,
  }) {
    if (_terminated) throw StateError('AlphaZero worker was stopped');
    if (_pending != null) throw StateError('AlphaZero worker is busy');
    final pending = _pending = Completer<Map<String, dynamic>>();
    _worker.postMessage(
      jsonEncode({'type': 'search', 'request': request}).toJS,
    );
    return pending.future.timeout(
      timeout,
      onTimeout: () {
        terminate();
        throw TimeoutException(
          'AlphaZero worker did not answer in time',
          timeout,
        );
      },
    );
  }

  void _onMessage(MessageEvent event) {
    final message = jsonDecode((event.data as JSString).toDart) as Map;
    switch (message['type']) {
      case 'result':
        _complete(
          (pending) =>
              pending.complete(message['result'] as Map<String, dynamic>),
        );
      case 'error':
        // An 'init' error arrives with no search pending; that search fails on its own.
        _complete(
          (pending) =>
              pending.completeError(StateError(message['message'] as String)),
        );
    }
  }

  void _onError(Event event) {
    final detail = event.isA<ErrorEvent>() ? (event as ErrorEvent).message : '';
    terminate(
      StateError(
        'AlphaZero worker failed${detail.isEmpty ? '' : ': $detail'} '
        '(is web/$alphaZeroWorkerScript built?)',
      ),
    );
  }

  void _complete(void Function(Completer<Map<String, dynamic>>) done) {
    final pending = _pending;
    _pending = null;
    if (pending != null) done(pending);
  }

  void terminate([Object? error]) {
    if (!_terminated) _worker.terminate();
    _terminated = true;
    _complete(
      (pending) => pending.completeError(
        error ?? StateError('AlphaZero search was stopped'),
      ),
    );
  }
}
