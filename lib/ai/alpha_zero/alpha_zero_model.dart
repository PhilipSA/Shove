import 'package:shove/ai/alpha_zero/az_network.dart';

/// Rules hash of the training checkout (its `lib/game_objects`) the exported weights
/// were trained against. Movement/termination sources are identical to this app's
/// (see README_ALPHAZERO.md); the hash differs here only through unrelated files.
const alphaZeroRulesHash =
    'baea03fb82e4d2cae8c3c9936901e987f38d44e90961ce09ce96f34df2df038a';

/// Larger files are rejected before reading; the exported champion is ~1.8 MB.
const alphaZeroMaxModelBytes = 20 * 1024 * 1024;

/// A validated `shove-az-dart-v1` weights file, loaded locally from the user's disk.
class AlphaZeroModel {
  final String fileName;
  final String json;
  final DartPolicyValue network;

  AlphaZeroModel._(this.fileName, this.json, this.network);

  /// Throws a [FormatException] with a readable message for unusable files.
  factory AlphaZeroModel.parse(String fileName, String json) {
    final DartPolicyValue network;
    try {
      network = DartPolicyValue.fromJson(json);
    } on FormatException catch (e) {
      throw FormatException(
        '$fileName is not a usable AlphaZero model: ${e.message}',
      );
    } catch (e) {
      // Wrongly typed JSON surfaces as a TypeError from the loader.
      throw FormatException('$fileName is not a usable AlphaZero model: $e');
    }
    if (network.rulesHash != alphaZeroRulesHash) {
      throw FormatException(
        '$fileName was trained for different rules '
        '(hash ${_short(network.rulesHash)}, expected ${_short(alphaZeroRulesHash)}).',
      );
    }
    return AlphaZeroModel._(fileName, json, network);
  }

  String get architecture =>
      network.localPolicy ? 'local-policy residual head' : 'legacy policy head';

  String get description =>
      '$fileName · ${(json.length / 1024).round()} KB · $architecture · '
      'checkpoint ${_short(network.checkpointHash)} · rules ${_short(network.rulesHash)}';

  static String _short(String hash) =>
      hash.length > 12 ? '${hash.substring(0, 12)}…' : hash;
}
