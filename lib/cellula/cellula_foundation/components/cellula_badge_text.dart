import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_icon.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/icon_asset.dart';

enum CellulaBadgeSize {
  small(CellulaSpacing.x2_5, CellulaFontLabel.xSmallRegular),
  medium(CellulaSpacing.x3, CellulaFontLabel.smallRegular);

  final CellulaSpacing size;
  final CellulaFontLabel fontVariant;

  const CellulaBadgeSize(this.size, this.fontVariant);
}

class CellulaBadgeTextVariant {
  final Color badgeColor;
  final Color textColor;

  CellulaBadgeTextVariant(this.badgeColor, this.textColor);

  // TODO(phsa): Prime candidate for sealed class when we upgrade to Dart 3
  CellulaBadgeTextVariant.interactive(CellulaTokens cellulaTokens)
      : this(cellulaTokens.bg.highlight, cellulaTokens.content.onHighlight);

  CellulaBadgeTextVariant.surfaceDarkBrand(CellulaTokens cellulaTokens)
      : this(cellulaTokens.bg.surfaceDarkBrand, cellulaTokens.content.onDark);

  CellulaBadgeTextVariant.surfaceBrand(CellulaTokens cellulaTokens)
      : this(cellulaTokens.bg.surfaceBrand, cellulaTokens.content.brand);

  CellulaBadgeTextVariant.surface(CellulaTokens cellulaTokens)
      : this(cellulaTokens.bg.surface, cellulaTokens.content.defaultColor);

  CellulaBadgeTextVariant.surfaceDark(CellulaTokens cellulaTokens)
      : this(cellulaTokens.bg.surfaceDark, cellulaTokens.content.onDark);

  CellulaBadgeTextVariant.success(CellulaTokens cellulaTokens)
      : this(cellulaTokens.success.bg, cellulaTokens.success.contentMuted);

  CellulaBadgeTextVariant.info(CellulaTokens cellulaTokens)
      : this(cellulaTokens.info.bg, cellulaTokens.info.contentMuted);

  CellulaBadgeTextVariant.warning(CellulaTokens cellulaTokens)
      : this(cellulaTokens.warning.bg, cellulaTokens.warning.contentMuted);

  CellulaBadgeTextVariant.danger(CellulaTokens cellulaTokens)
      : this(cellulaTokens.danger.bg, cellulaTokens.danger.contentMuted);
}

class CellulaBadgeText extends StatelessWidget {
  final IconAsset? icon;
  final String text;
  final CellulaBadgeTextVariant cellulaBadgeTextVariant;
  final CellulaBadgeSize cellulaBadgeSize;

  const CellulaBadgeText({
    required this.text,
    required this.cellulaBadgeTextVariant,
    required this.cellulaBadgeSize,
    super.key,
    this.icon,
  });

  EdgeInsets _padding() {
    switch (cellulaBadgeSize) {
      case CellulaBadgeSize.small:
        return EdgeInsets.fromLTRB(
          CellulaSpacing.x1.spacing,
          0,
          CellulaSpacing.x1.spacing,
          0,
        );
      case CellulaBadgeSize.medium:
        return EdgeInsets.fromLTRB(
          CellulaSpacing.x1.spacing,
          0,
          CellulaSpacing.x1.spacing,
          0,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: cellulaBadgeSize.size.spacing,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cellulaBadgeTextVariant.badgeColor,
          borderRadius: BorderRadius.circular(CellulaBorderRadius.small.value),
        ),
        child: Padding(
          padding: _padding(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null)
                Padding(
                  padding: EdgeInsets.only(right: CellulaSpacing.x0_5.spacing),
                  child: CellulaIcon(
                    iconAsset: icon,
                    size: cellulaBadgeSize == CellulaBadgeSize.small
                        ? IconSize.small
                        : IconSize.medium,
                    color: cellulaBadgeTextVariant.textColor,
                    padding: EdgeInsets.zero,
                  ),
                ),
              Flexible(
                child: CellulaText(
                  text: text,
                  color: cellulaBadgeTextVariant.textColor,
                  fontVariant: cellulaBadgeSize.fontVariant.fontVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
