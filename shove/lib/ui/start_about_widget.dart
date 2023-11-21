import 'package:flutter/material.dart';
import 'package:shove/about_board_widget.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_button.dart';

class AboutButton extends StatelessWidget {
  const AboutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return CellulaButton(
      buttonVariant: CellulaButtonVariant.secondary(
          CellulaTokens.none(), CellulaButtonSize.large),
      text: 'About',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const About()),
        );
      },
    );
  }
}
