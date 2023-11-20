import 'package:flutter/material.dart';
import 'package:shove/about_board_widget.dart';

class AboutButton extends StatelessWidget {
  const AboutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // Navigate to a new route when the button is pressed
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  const About()), // Replace SecondRoute with the route you want to navigate to
        );
      },
      child: const Text('About'),
    );
  }
}
