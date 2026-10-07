// Entry point of web/alpha_zero_worker.js (compiled by tool/build_web_workers.sh).
import 'dart:convert';
import 'dart:js_interop';

import 'package:shove/ai/alpha_zero/alpha_zero_model.dart';
import 'package:shove/ai/alpha_zero/alpha_zero_protocol.dart';
import 'package:shove/ai/alpha_zero/az_network.dart';
import 'package:web/web.dart';

void main() {
  final scope = globalContext as DedicatedWorkerGlobalScope;
  DartPolicyValue? network;
  String? loadError;
  void reply(Map<String, Object?> message) =>
      scope.postMessage(jsonEncode(message).toJS);

  void onMessage(MessageEvent event) {
    try {
      final message =
          jsonDecode((event.data as JSString).toDart) as Map<String, dynamic>;
      switch (message['type']) {
        case 'init':
          try {
            network = DartPolicyValue.fromJson(
              message['weights'] as String,
              expectedRulesHash: alphaZeroRulesHash,
            );
          } catch (e) {
            loadError = '$e';
            reply({'type': 'error', 'message': 'Model failed to load: $e'});
          }
        case 'search':
          final loaded = network;
          if (loaded == null) {
            reply({
              'type': 'error',
              'message': 'Model failed to load: $loadError',
            });
            return;
          }
          runAlphaZeroRequest(
            loaded,
            message['request'] as Map<String, dynamic>,
          ).then(
            (result) => reply({'type': 'result', 'result': result}),
            onError: (Object e) => reply({'type': 'error', 'message': '$e'}),
          );
      }
    } catch (e) {
      reply({'type': 'error', 'message': 'Bad worker message: $e'});
    }
  }

  scope.onmessage = onMessage.toJS;
}
