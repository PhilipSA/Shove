import 'package:flutter/material.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/ui/start_about_widget.dart';
import 'package:shove/ui/start_play_widget.dart';

class StartScreen extends StatelessWidget {
  final ShoveAudioPlayer audioPlayer;

  const StartScreen(this.audioPlayer, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        child: Column(
          children: [
            Flexible(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
                child: PlayButton(audioPlayer),
              ),
            ),
            Flexible(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
                child: const AboutButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Example of a second route


