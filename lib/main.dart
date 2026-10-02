import 'package:flutter/material.dart';
import 'package:shove/audio/shove_audio_player.dart';
import 'package:shove/ui/start_screen.widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final ShoveAudioPlayerFactory createAudioPlayer;

  const MyApp({this.createAudioPlayer = ShoveAudioPlayer.new, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shove',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(title: 'Shove', createAudioPlayer: createAudioPlayer),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({
    super.key,
    required this.title,
    this.createAudioPlayer = ShoveAudioPlayer.new,
  });

  final String title;
  final ShoveAudioPlayerFactory createAudioPlayer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: StartScreen(createAudioPlayer: createAudioPlayer),
    );
  }
}
