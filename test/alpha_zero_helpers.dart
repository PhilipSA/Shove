import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shove/ai/alpha_zero/alpha_zero_model.dart';

/// Frozen exported weights copied by hand into this ignored folder (see README_ALPHAZERO.md).
const fixtures = 'test/alpha_zero_fixtures';

File fixture(String name) => File('$fixtures/$name');

/// A small deterministic `shove-az-dart-v1` file with the real tensor shapes.
String syntheticWeights({
  bool localPolicy = true,
  String rulesHash = alphaZeroRulesHash,
}) {
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
    if (localPolicy) ...{
      'local_policy.0.weight': [64, 143],
      'local_policy.0.bias': [64],
      'local_policy.2.weight': [1, 64],
      'local_policy.2.bias': [1],
    },
  };
  var seed = 0;
  return jsonEncode({
    'format': 'shove-az-dart-v1',
    'encoding': 'shove-az-v2-relative',
    'rulesHash': rulesHash,
    'checkpointSha256': 'synthetic-checkpoint-for-tests',
    'localPolicy': localPolicy,
    'tensors': {
      for (final MapEntry(:key, :value) in shapes.entries)
        key: {
          'shape': value,
          'data': [
            for (var i = 0; i < value.reduce((a, b) => a * b); i++)
              0.05 * sin(seed++ * 0.37),
          ],
        },
    },
  });
}

final syntheticModel = AlphaZeroModel.parse(
  'synthetic.json',
  syntheticWeights(),
);

/// The real exported champion when present, otherwise the synthetic model.
AlphaZeroModel testModel() => fixture('weights.json').existsSync()
    ? AlphaZeroModel.parse(
        'weights.json',
        fixture('weights.json').readAsStringSync(),
      )
    : syntheticModel;
