import 'package:flutter/material.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_button.dart';
import 'package:shove/ui/puzzles/puzzle_list_widget.dart';

class PuzzlesButton extends StatelessWidget {
  final ShoveAudioPlayerFactory createAudioPlayer;

  const PuzzlesButton({
    this.createAudioPlayer = ShoveAudioPlayer.new,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CellulaButton(
      buttonVariant: CellulaButtonVariant.secondary(
        CellulaTokens.none(),
        CellulaButtonSize.large,
      ),
      text: 'Puzzles',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PuzzleListScreen(createAudioPlayer: createAudioPlayer),
          ),
        );
      },
    );
  }
}
