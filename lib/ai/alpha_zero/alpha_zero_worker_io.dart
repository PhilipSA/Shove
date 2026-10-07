import 'dart:async';
import 'dart:isolate';

import 'package:shove/ai/alpha_zero/alpha_zero_model.dart';
import 'package:shove/ai/alpha_zero/alpha_zero_protocol.dart';
import 'package:shove/ai/alpha_zero/az_network.dart';

// Top-level so the isolate closure captures only what it needs to send.
Future<Map<String, Object?>> _searchInIsolate(
  DartPolicyValue network,
  Map<String, Object?> request,
) => Isolate.run(() => runAlphaZeroRequest(network, request));

/// Runs each search in a short-lived isolate (native builds and tests).
class AlphaZeroWorker {
  final AlphaZeroModel model;
  Completer<Map<String, dynamic>>? _pending;

  AlphaZeroWorker(this.model);

  Future<Map<String, dynamic>> search(
    Map<String, Object?> request, {
    required Duration timeout,
  }) {
    if (_pending != null) throw StateError('AlphaZero worker is busy');
    final pending = _pending = Completer<Map<String, dynamic>>();
    _searchInIsolate(model.network, request).then(
      (result) => _finish(pending, () => pending.complete(result)),
      onError: (Object e, StackTrace s) =>
          _finish(pending, () => pending.completeError(e, s)),
    );
    return pending.future.timeout(
      timeout,
      onTimeout: () {
        _pending = null;
        throw TimeoutException('AlphaZero did not answer in time', timeout);
      },
    );
  }

  void _finish(Completer<Map<String, dynamic>> pending, void Function() done) {
    if (!identical(_pending, pending)) return; // Terminated or timed out.
    _pending = null;
    done();
  }

  /// An isolate started by [Isolate.run] cannot be killed; its answer is ignored.
  void terminate() {
    final pending = _pending;
    _pending = null;
    pending?.completeError(StateError('AlphaZero search was stopped'));
  }
}
