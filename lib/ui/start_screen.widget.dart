import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/ui/about/start_about_widget.dart';
import 'package:shove/ui/play/start_play_widget.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({Key? key}) : super(key: key);

  @override
  createState() => StartScreenState();
}

class StartScreenState extends State<StartScreen> {
  late final ShoveAudioPlayer audioPlayer;

  @override
  void initState() {
    super.initState();
    audioPlayer = ShoveAudioPlayer(playerId: 'music');
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

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
