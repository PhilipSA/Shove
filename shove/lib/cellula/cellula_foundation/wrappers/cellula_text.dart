import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';

class CellulaText extends StatelessWidget {
  final String text;
  final Color color;
  final CellulaFontVariant fontVariant;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool? isSelectable;
  final TextOverflow? textOverflow;
  final Color? linkColor;
  final TextStyle? textStyle;

  const CellulaText({
    required this.text,
    required this.color,
    required this.fontVariant,
    super.key,
    this.textAlign,
    this.maxLines,
    this.isSelectable,
    this.textOverflow,
    this.linkColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    assert(
      isSelectable != true || linkColor != null,
      'If text isSelectable then linkColor must have a color set otherwise links will have wrong color',
    );

    final textStyle = TextStyle(
      color: color,
      height: fontVariant.lineHeight / fontVariant.fontSize,
      fontSize: fontVariant.fontSize,
      fontWeight: fontVariant.fontWeight,
      overflow: textOverflow,
      fontFamily: null,
    ).merge(this.textStyle);

    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: textOverflow,
      style: textStyle,
    );
  }
}
