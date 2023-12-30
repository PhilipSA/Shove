import 'package:shove/ai/abstraction/i_ai.dart';
import 'package:shove/game_objects/abstraction/i_player.dart';
import 'package:shove/game_objects/dto/shove_game_state_dto.dart';
import 'package:shove/game_objects/game_state/shove_game_evaluator_service.dart';
import 'package:shove/game_objects/shove_game.dart';
import 'package:shove/game_objects/shove_game_move.dart';

class MinMaxAi extends IPlayer implements IAi {
  MinMaxAi(super.playerName, super.isWhite);
  final stopwatch = Stopwatch();

  @override
  Future<ShoveGameMove> makeMove(ShoveGame game) async {
    stopwatch.start();

    final worker = ShoveGameEvaluatorServiceWorker();
    final bestMove =
        await worker.findBestMove(ShoveGameStateDto.fromGame(game));
    worker.stop();

    stopwatch.stop();
    stopwatch.reset();
    return bestMove.$2!;
  }
}
