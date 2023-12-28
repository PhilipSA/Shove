import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';

enum CellulaBadgeNumberSize {
  small(CellulaFontLabel.xSmallSemiBold, CellulaSpacing.x2),
  medium(CellulaFontLabel.smallSemiBold, CellulaSpacing.x2_5);

  final CellulaFontLabel cellulaFontLabel;
  final CellulaSpacing cellulaSpacing;

  const CellulaBadgeNumberSize(this.cellulaFontLabel, this.cellulaSpacing);
}

class CellulaBadgeNumberVariant {
  final Color backgroundColor;
  final Color textColor;
  final CellulaBadgeNumberSize cellulaBadgeNumberSize;

  CellulaBadgeNumberVariant(
    this.backgroundColor,
    this.textColor,
    this.cellulaBadgeNumberSize,
  );

  CellulaBadgeNumberVariant.interactive(
    CellulaTokens cellulaTokens,
    CellulaBadgeNumberSize cellulaBadgeNumberSize,
  ) : this(
          cellulaTokens.bg.highlight,
          cellulaTokens.content.onHighlight,
          cellulaBadgeNumberSize,
        );

  CellulaBadgeNumberVariant.surfaceDarkBrand(
    CellulaTokens cellulaTokens,
    CellulaBadgeNumberSize cellulaBadgeNumberSize,
  ) : this(
          cellulaTokens.bg.surfaceDarkBrand,
          cellulaTokens.content.onDark,
          cellulaBadgeNumberSize,
        );

  CellulaBadgeNumberVariant.surfaceBrand(
    CellulaTokens cellulaTokens,
    CellulaBadgeNumberSize cellulaBadgeNumberSize,
  ) : this(
          cellulaTokens.bg.surfaceBrand,
          cellulaTokens.content.brand,
          cellulaBadgeNumberSize,
        );

  CellulaBadgeNumberVariant.surface(
    CellulaTokens cellulaTokens,
    CellulaBadgeNumberSize cellulaBadgeNumberSize,
  ) : this(
          cellulaTokens.bg.surface,
          cellulaTokens.content.defaultColor,
          cellulaBadgeNumberSize,
        );

  CellulaBadgeNumberVariant.surfaceDark(
    CellulaTokens cellulaTokens,
    CellulaBadgeNumberSize cellulaBadgeNumberSize,
  ) : this(
          cellulaTokens.bg.surfaceDark,
          cellulaTokens.content.onDark,
          cellulaBadgeNumberSize,
        );
}

class CellulaBadgeNumber extends StatelessWidget {
  final String text;
  final CellulaBadgeNumberVariant cellulaBadgeNumberVariant;
  final String semanticDescription;

  const CellulaBadgeNumber({
    required this.text,
    required this.cellulaBadgeNumberVariant,
    required this.semanticDescription,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cellulaBadgeNumberVariant
          .cellulaBadgeNumberSize.cellulaSpacing.spacing,
      height: cellulaBadgeNumberVariant
          .cellulaBadgeNumberSize.cellulaSpacing.spacing,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cellulaBadgeNumberVariant.backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Semantics(
          label: semanticDescription,
          excludeSemantics: true,
          child: CellulaText(
            text: text,
            color: cellulaBadgeNumberVariant.textColor,
            fontVariant: cellulaBadgeNumberVariant
                .cellulaBadgeNumberSize.cellulaFontLabel.fontVariant,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
