// Browser-compatible inference for the experiment's frozen PyTorch network.
// Copied from the training checkout's experiments/alphazero/dart_network.dart.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

class AzPrediction {
  final List<double> logits;
  final List<double> policy;
  final double value;
  AzPrediction(this.logits, this.policy, this.value);
}

class DartPolicyValue {
  final Map<String, Float64List> _weights = {};
  final bool localPolicy;
  final String rulesHash;
  final String checkpointHash;

  DartPolicyValue._(this.localPolicy, this.rulesHash, this.checkpointHash);

  factory DartPolicyValue.fromJson(String text, {String? expectedRulesHash}) {
    final data = jsonDecode(text) as Map<String, dynamic>;
    if (data['format'] != 'shove-az-dart-v1' ||
        data['encoding'] != 'shove-az-v2-relative' ||
        data['localPolicy'] is! bool ||
        data['rulesHash'] is! String ||
        data['checkpointSha256'] is! String) {
      throw const FormatException('Unsupported AlphaZero weights');
    }
    if (expectedRulesHash != null && data['rulesHash'] != expectedRulesHash) {
      throw const FormatException('AlphaZero rules hash mismatch');
    }
    final net = DartPolicyValue._(
      data['localPolicy'],
      data['rulesHash'],
      data['checkpointSha256'],
    );
    final shapes = <String, List<int>>{
      'board.0.weight': [16, 24, 3, 3],
      'board.0.bias': [16],
      'board.2.weight': [16, 16, 3, 3],
      'board.2.bias': [16],
      'board.5.weight': [64, 1024],
      'board.5.bias': [64],
      'value.weight': [1, 64],
      'value.bias': [1],
      'policy.weight': [32, 64],
      'policy.bias': [32],
      for (var i = 0; i < 3; i++) 'squares.$i.weight': [65, 8],
      'action.0.weight': [32, 24],
      'action.0.bias': [32],
      if (net.localPolicy) ...{
        'local_policy.0.weight': [64, 143],
        'local_policy.0.bias': [64],
        'local_policy.2.weight': [1, 64],
        'local_policy.2.bias': [1],
      },
    };
    final tensors = data['tensors'] as Map<String, dynamic>;
    if (tensors.length != shapes.length) {
      throw const FormatException('Unexpected AlphaZero parameters');
    }
    for (final entry in shapes.entries) {
      final tensor = tensors[entry.key] as Map<String, dynamic>?;
      if (tensor == null ||
          jsonEncode(tensor['shape']) != jsonEncode(entry.value)) {
        throw FormatException('Wrong tensor shape: ${entry.key}');
      }
      final values = tensor['data'] as List;
      final count = entry.value.reduce((a, b) => a * b);
      if (values.length != count ||
          values.any((v) => v is! num || !v.isFinite)) {
        throw FormatException('Invalid tensor values: ${entry.key}');
      }
      net._weights[entry.key] = Float64List.fromList([
        for (final v in values) (v as num).toDouble(),
      ]);
    }
    return net;
  }

  static double _tanh(double x) {
    // Stable for large magnitudes; Dart's math library has no tanh.
    final e = math.exp(-2 * x.abs());
    final value = (1 - e) / (1 + e);
    return x < 0 ? -value : value;
  }

  Float64List _dense(String name, List<double> input) {
    final weights = _weights['$name.weight']!;
    final bias = _weights['$name.bias']!;
    final out = Float64List(bias.length);
    for (var o = 0; o < out.length; o++) {
      var sum = bias[o];
      final offset = o * input.length;
      for (var i = 0; i < input.length; i++) {
        sum += weights[offset + i] * input[i];
      }
      out[o] = sum;
    }
    return out;
  }

  Float64List _conv(String name, Float64List input, int channels) {
    final weights = _weights['$name.weight']!;
    final bias = _weights['$name.bias']!;
    final out = Float64List(16 * 64);
    // ponytail: scalar convolution; SIMD/WASM if measured browser speed is insufficient.
    for (var o = 0; o < 16; o++) {
      for (var row = 0; row < 8; row++) {
        for (var col = 0; col < 8; col++) {
          var sum = bias[o];
          for (var c = 0; c < channels; c++) {
            final base = (o * channels + c) * 9;
            for (var dr = 0; dr < 3; dr++) {
              final r = row + dr - 1;
              if (r < 0 || r >= 8) continue;
              for (var dc = 0; dc < 3; dc++) {
                final column = col + dc - 1;
                if (column < 0 || column >= 8) continue;
                sum +=
                    input[c * 64 + r * 8 + column] *
                    weights[base + dr * 3 + dc];
              }
            }
          }
          out[o * 64 + row * 8 + col] = math.max(0.0, sum);
        }
      }
    }
    return out;
  }

  AzPrediction predict(List<int> board, int turn, List<List<int>> moves) {
    if (board.length != 64 ||
        board.any((v) => v < 0 || v > 24) ||
        (turn != 0 && turn != 1) ||
        moves.isEmpty ||
        moves.any(
          (m) =>
              m.length != 3 ||
              m[0] < 0 ||
              m[0] >= 64 ||
              m[1] < 0 ||
              m[1] >= 64 ||
              m[2] < 0 ||
              m[2] > 64,
        )) {
      throw ArgumentError('Invalid board, turn or legal move encoding');
    }
    int reflect(int square) =>
        turn == 0 || square == 64 ? square : (7 - square ~/ 8) * 8 + square % 8;
    final input = Float64List(24 * 64);
    for (var square = 0; square < 64; square++) {
      final code = board[square] - 1;
      if (code < 0) continue;
      final channel =
          code % 6 + ((code ~/ 6) % 2 != turn ? 6 : 0) + (code ~/ 12) * 12;
      input[channel * 64 + reflect(square)] = 1;
    }
    final features = _conv('board.2', _conv('board.0', input, 24), 16);
    final hidden = _dense('board.5', features);
    for (var i = 0; i < hidden.length; i++) {
      hidden[i] = math.max(0.0, hidden[i]);
    }
    final context = _dense('policy', hidden);
    final logits = <double>[];
    for (final move in moves) {
      final ids = [for (final square in move) reflect(square)];
      final embedding = Float64List(24);
      for (var i = 0; i < 3; i++) {
        final weights = _weights['squares.$i.weight']!;
        for (var j = 0; j < 8; j++) {
          embedding[i * 8 + j] = weights[ids[i] * 8 + j];
        }
      }
      final action = _dense('action.0', embedding);
      var score = 0.0;
      for (var i = 0; i < 32; i++) {
        score += _tanh(action[i]) * context[i];
      }
      score /= math.sqrt(32);
      if (localPolicy) {
        final local = <double>[
          for (final id in ids)
            for (var c = 0; c < 16; c++) id == 64 ? 0 : features[c * 64 + id],
          ...embedding,
          ...hidden,
          for (final id in ids) (id == 64 ? 0 : id ~/ 8) / 7,
          for (final id in ids) (id == 64 ? 0 : id % 8) / 7,
          ids[2] == 64 ? 0 : 1,
        ];
        final residual = _dense('local_policy.0', local);
        for (var i = 0; i < residual.length; i++) {
          residual[i] = math.max(0.0, residual[i]);
        }
        score += _dense('local_policy.2', residual)[0];
      }
      logits.add(score);
    }
    final maximum = logits.reduce(math.max);
    final exps = [for (final logit in logits) math.exp(logit - maximum)];
    final sum = exps.reduce((a, b) => a + b);
    return AzPrediction(logits, [
      for (final e in exps) e / sum,
    ], _tanh(_dense('value', hidden)[0]));
  }
}
