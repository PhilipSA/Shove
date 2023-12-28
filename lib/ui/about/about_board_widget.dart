import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_icon_text.dart';
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
            fontVariant: CellulaFontLabel.regular.fontVariant),
      ),
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconText(
            asset: 'assets/textures/knuffare.svg',
            text:
                'The goal of the game is to get one of your shovers into your opponents back rank. Shovers can move one step forward or sideways. Shovers can also shove other pieces except for blockers. Shoved pieces are incapacitated for one turn.',
          ),
          _IconText(
            asset: 'assets/textures/kastare.svg',
            text:
                'Thrower can move one step in any direction. Throwers can also throw other pieces to one open square surronding them except for blockers. Pieces next to blockers can not be thrown. Pieces that are thrown are incapacitated for one turn.',
          ),
          _IconText(
            asset: 'assets/textures/ankare.svg',
            text:
                'Blockers can move one or two steps horizontally or vertically. Blockers can not be shoved or thrown. Friendly pieces standing next to blockers can not be thrown.',
          ),
          _IconText(
            asset: 'assets/textures/hoppare.svg',
            text: 'Leapers are useless don\'t bother',
          ),
        ],
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  final String asset;
  final String text;
  final double spacing; // space between the icon and the text

  const _IconText({
    Key? key,
    required this.asset,
    required this.text,
    this.spacing = 8.0, // default spacing
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
          MainAxisSize.min, // to constrain the row to the width of its children
      children: <Widget>[
        SvgPicture.asset(asset, width: 48, height: 48),
        SizedBox(width: spacing),
        Flexible(
          child: CellulaText(
              text: text,
              color: CellulaTokens.none().content.defaultColor,
              fontVariant: CellulaFontLabel.regular.fontVariant),
        ),
      ],
    );
  }
}
