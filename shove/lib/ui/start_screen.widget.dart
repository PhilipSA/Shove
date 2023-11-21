import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/ui/start_about_widget.dart';
import 'package:shove/ui/start_play_widget.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
              child: const PlayButton(),
            ),
            Padding(
              padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
              child: const AboutButton(),
            )
          ],
        ),
      ),
    );
  }
}

// Example of a second route


