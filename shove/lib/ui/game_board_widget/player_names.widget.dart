import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_textinput.dart';

class PlayerTextBox extends StatelessWidget {
  const PlayerTextBox({super.key});

  @override
  Widget build(BuildContext context) {
    return CellulaTextInput(
      cellulaTokens: CellulaTokens.none(),
      placeholderText: '',
      onChanged: (String) {},
      readOnly: true,
    );
  }
}
