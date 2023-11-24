import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

class ShoveAudioPlayer {
  final AudioPlayer _audioPlayer;
  final String? playerId;

  ShoveAudioPlayer({this.playerId})
      : _audioPlayer = AudioPlayer(playerId: playerId);

  Future<void> play(AssetSource assetSource, {double? volume}) async {
    try {
      await _audioPlayer.play(assetSource, volume: volume);
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    _audioPlayer.setReleaseMode(releaseMode);
  }

  void dispose() {
    _audioPlayer.dispose();
  }

  void stop() {
    _audioPlayer.stop();
  }

  void pause() {
    _audioPlayer.pause();
  }

  void resume() {
    _audioPlayer.resume();
  }
}
