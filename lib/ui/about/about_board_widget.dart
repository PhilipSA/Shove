import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';

class About extends StatelessWidget {
  const About({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CellulaText(
          text: 'About',
          color: CellulaTokens.none().content.defaultColor,
          fontVariant: CellulaFontLabel.regular.fontVariant,
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconText(
              asset: 'assets/textures/knuffare.svg',
              text: 'Shover: moves one step forward or sideways. Moving into an enemy (not a blocker) shoves it one square further, stunning it. Shove a piece off the board to eliminate it. Get a shover to the opponent\'s back rank (the gold row) to win.',
            ),
            _IconText(
              asset: 'assets/textures/kastare.svg',
              text: 'Thrower: moves one step in any direction. Can instead throw an adjacent enemy (not a blocker) to any empty square next to the thrower, stunning it. Throws always land on the board.',
            ),
            _IconText(
              asset: 'assets/textures/ankare.svg',
              text: 'Blocker: moves one or two steps horizontally or vertically. Cannot be shoved or thrown, and friendly pieces next to it cannot be thrown.',
            ),
            _IconText(
              asset: 'assets/textures/hoppare.svg',
              text: 'Leaper: moves one step in any direction, or leaps in a straight or diagonal line over an adjacent piece. Leaping over an enemy stuns it.',
            ),
            _RuleText(
              'Stunned pieces are greyed out and skip their next turn.\n'
              'You lose if you run out of shovers or have no legal moves.\n'
              'Repeating the same moves over and over ends in a draw.\n'
              'Tap or drag a piece to see where it can go.',
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleText extends StatelessWidget {
  final String text;

  const _RuleText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: CellulaText(
        text: text,
        color: CellulaTokens.none().content.defaultColor,
        fontVariant: CellulaFontLabel.regular.fontVariant,
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  final String asset;
  final String text;
  final double spacing; // space between the icon and the text

  const _IconText({required this.asset, required this.text}) : spacing = 8.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          SvgPicture.asset(asset, width: 48, height: 48),
          SizedBox(width: spacing),
          Flexible(
            child: CellulaText(
              text: text,
              color: CellulaTokens.none().content.defaultColor,
              fontVariant: CellulaFontLabel.regular.fontVariant,
            ),
          ),
        ],
      ),
    );
  }
}
