import 'package:flutter/material.dart';
import 'package:shove/ui/game_board_widget/shove_board_widget.dart';
import 'package:shove/shove_game.dart';

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
              builder: (context) => ChessBoardWidget(
                    game: ShoveGame(),
                  )), // Replace SecondRoute with the route you want to navigate to
        );
      },
      child: const Text('Play'),
    );
  }
}
