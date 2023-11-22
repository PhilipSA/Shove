import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_badge_text.dart';

class PlayerTextBox extends StatelessWidget {
  final String playerName;
  const PlayerTextBox(this.playerName, {super.key});

  @override
  Widget build(BuildContext context) {
    return CellulaBadgeText(
      text: playerName,
      cellulaBadgeTextVariant:
          CellulaBadgeTextVariant.info(CellulaTokens.none()),
      cellulaBadgeSize: CellulaBadgeSize.medium,
      // color: CellulaTokens.none().content.defaultColor,
      // fontVariant: CellulaFontHeading.medium.fontVariant,
    );
  }
}
