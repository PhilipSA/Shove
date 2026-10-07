import 'dart:async';
import 'dart:js_interop';

import 'package:shove/ai/alpha_zero/alpha_zero_model.dart';
import 'package:shove/ui/play/model_file_picker.dart';
import 'package:web/web.dart';

/// Opens the browser's file picker and reads the chosen JSON file locally.
/// Completes with null when the picker is cancelled.
Future<PickedModelFile?> pickAlphaZeroModelFile() {
  final picked = Completer<PickedModelFile?>();
  final input = HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json';
  input.addEventListener(
    'cancel',
    ((Event _) {
      if (!picked.isCompleted) picked.complete(null);
    }).toJS,
  );
  input.addEventListener(
    'change',
    ((Event _) {
      final file = input.files?.item(0);
      if (file == null) {
        if (!picked.isCompleted) picked.complete(null);
        return;
      }
      if (file.size > alphaZeroMaxModelBytes) {
        picked.completeError(
          FormatException(
            '${file.name} is ${(file.size / 1024 / 1024).toStringAsFixed(1)} MB; '
            'models over ${alphaZeroMaxModelBytes ~/ 1024 ~/ 1024} MB are rejected.',
          ),
        );
        return;
      }
      file.text().toDart.then(
        (text) => picked.complete((name: file.name, text: text.toDart)),
        onError: (Object e) => picked.completeError(
          FormatException('Could not read ${file.name}: $e'),
        ),
      );
    }).toJS,
  );
  input.click();
  return picked.future;
}
