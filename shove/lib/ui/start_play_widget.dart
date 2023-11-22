import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_button.dart';
import 'package:shove/player_selection_widget.dart';

class PlayButton extends StatelessWidget {
  final AudioPlayer audioPlayer;

  const PlayButton(this.audioPlayer, {super.key});

  @override
  Widget build(BuildContext context) {
    return CellulaButton(
      mainAxisSize: MainAxisSize.max,
      buttonVariant: CellulaButtonVariant.primary(
          CellulaTokens.none(), CellulaButtonSize.xLarge),
      text: 'Play',
      onPressed: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => PlayersWidget(audioPlayer)));
      },
    );
  }
}
