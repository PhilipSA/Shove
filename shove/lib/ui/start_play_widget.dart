import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_button.dart';
import 'package:shove/ui/game_board_widget/shove_board_widget.dart';
import 'package:shove/shove_game.dart';

class PlayButton extends StatelessWidget {
  const PlayButton({super.key});

  @override
  Widget build(BuildContext context) {
    return CellulaButton(
      buttonVariant: CellulaButtonVariant.primary(
          CellulaTokens.none(), CellulaButtonSize.xLarge),
      text: 'Play',
      onPressed: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ShoveBoardWidget(
                      game: ShoveGame(),
                    )));
      },
    );
  }
}
