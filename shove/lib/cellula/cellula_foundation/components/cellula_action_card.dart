import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_icon.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/icon_asset.dart';

class CellulaActionCard extends StatelessWidget {
  final CellulaTokens cellulaTokens;
  final String title;
  final String? subtitle;
  final IconAsset? iconAsset;
  final String? iconUrl;
  final bool enabled;
  final bool useIconAutomaticIconColor;
  final Function() onPressed;

  const CellulaActionCard({
    required this.cellulaTokens,
    required this.title,
    required this.iconAsset,
    required this.iconUrl,
    required this.onPressed,
    this.enabled = true,
    this.useIconAutomaticIconColor = true,
    super.key,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = CellulaSpacing.x1_5.spacing;
    final verticalPadding = CellulaSpacing.x1_5.spacing;
    final borderRadius = CellulaBorderRadius.medium.value;
    final hasIcon = iconAsset != null || iconUrl != null;

    return ElevatedButton(
      style: ButtonStyle(
        padding: MaterialStateProperty.all(
          const EdgeInsets.symmetric(
            vertical: 0.0,
            horizontal: 0.0,
          ),
        ),
        backgroundColor: MaterialStateProperty.all(
          cellulaTokens.bg.surface.getCellulaDisabledColorIfDisabled(enabled),
        ),
        surfaceTintColor: MaterialStateProperty.all(
          cellulaTokens.bg.surface.getCellulaDisabledColorIfDisabled(enabled),
        ),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(
            side: BorderSide(color: cellulaTokens.border.defaultColor),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        visualDensity: VisualDensity.standard,
        minimumSize: MaterialStateProperty.all(
          Size.fromHeight(
            CellulaSpacing.x9.spacing,
          ),
        ),
      ),
      onPressed: enabled ? onPressed : null,
      child: Row(
        children: [
          if (hasIcon)
            CellulaIcon(
              iconAsset: iconAsset,
              iconUrl: iconUrl,
              size: IconSize.large,
              color: useIconAutomaticIconColor
                  ? cellulaTokens.content.mutedBrand
                      .getCellulaDisabledColorIfDisabled(enabled)
                  : null,
              padding: EdgeInsets.symmetric(
                vertical: CellulaSpacing.x2_5.spacing,
                horizontal: horizontalPadding,
              ),
              backgroundColor: cellulaTokens.bg.surfaceBrand
                  .getCellulaDisabledColorIfDisabled(enabled),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(borderRadius),
                bottomLeft: Radius.circular(borderRadius),
              ),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: verticalPadding,
                horizontal: CellulaSpacing.x2.spacing,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CellulaText(
                    text: title,
                    color: cellulaTokens.content.defaultColor
                        .getCellulaDisabledColorIfDisabled(enabled),
                    fontVariant: CellulaFontLabel.largeSemiBold.fontVariant,
                  ),
                  if (subtitle != null)
                    Padding(
                      padding:
                          EdgeInsets.only(top: CellulaSpacing.x0_5.spacing),
                      child: CellulaText(
                        text: subtitle!,
                        color: cellulaTokens.content.muted,
                        fontVariant: CellulaFontLabel.smallRegular.fontVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (enabled)
            Padding(
              padding: EdgeInsets.only(right: CellulaSpacing.x1_5.spacing),
              child: CellulaIcon(
                iconAsset: IconAsset.arrowRight,
                size: IconSize.medium,
                color: cellulaTokens.content.muted,
              ),
            ),
        ],
      ),
    );
  }
}
