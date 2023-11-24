import 'package:audioplayers/audioplayers.dart';

class ShoveAudioPlayer {
  final AudioPlayer _audioPlayer;
  final String? playerId;

  ShoveAudioPlayer({this.playerId})
      : _audioPlayer = AudioPlayer(playerId: playerId);

  Future<void> play(AssetSource assetSource, {double? volume}) async {
    try {
      _audioPlayer.onPlayerComplete.listen((event) {
        dispose();
      });

      await _audioPlayer.play(assetSource,
          volume: volume, mode: PlayerMode.mediaPlayer);
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    _audioPlayer.setReleaseMode(releaseMode);
  }

  Future<void> dispose() async {
    await _audioPlayer.dispose();
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
