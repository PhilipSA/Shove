import 'package:flutter/material.dart';
import 'package:shove/chess_board_widget.dart';

class PlayButton extends StatelessWidget {
  const PlayButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // Navigate to a new route when the button is pressed
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  const ChessBoardWidget()), // Replace SecondRoute with the route you want to navigate to
        );
      },
      child: const Text('Play'),
    );
  }
}
