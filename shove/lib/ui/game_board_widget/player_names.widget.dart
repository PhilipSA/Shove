import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';

class PlayerTextBox extends StatelessWidget {
  const PlayerTextBox(String playerName, {super.key});

  @override
  Widget build(BuildContext context) {
    return CellulaText(
      text: '',
      color: Colors.black,
      fontVariant: CellulaFontLabel.regular.fontVariant,
    );
  }
}
