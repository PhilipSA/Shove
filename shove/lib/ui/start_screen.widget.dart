import 'package:flutter/material.dart';
import 'package:shove/start_about_widget.dart';
import 'package:shove/start_play_widget.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 200.0, // Set a fixed width for the container
        height: 80.0, // Set a fixed height for the container

        child: Column(
          children: [PlayButton(), AboutButton()],
        ),
      ),
    );
  }
}

// Example of a second route


