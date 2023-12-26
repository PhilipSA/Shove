import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_button.dart';
import 'package:shove/ui/play/player_selection_widget.dart';

class PlayButton extends StatelessWidget {
  final ShoveAudioPlayer audioPlayer;

  const PlayButton(this.audioPlayer, {super.key});

  Future<void> _playAudio() async {
    try {
      await audioPlayer.setReleaseMode(ReleaseMode.loop);
      await audioPlayer.play(AssetSource('sounds/music/Action_2.mp3'),
          volume: 0.05); // will immediately start playing
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return CellulaButton(
      mainAxisSize: MainAxisSize.max,
      buttonVariant: CellulaButtonVariant.primary(
          CellulaTokens.none(), CellulaButtonSize.xLarge),
      text: 'Play',
      onPressed: () {
        _playAudio();
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => PlayersWidget(audioPlayer)));
      },
    );
  }
}
