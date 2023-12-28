import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_icon.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/icon_asset.dart';

enum CellulaIconButtonSize {
  small(CellulaSpacing.x2_5),
  medium(CellulaSpacing.x3),
  large(CellulaSpacing.x4);

  final CellulaSpacing spacing;

  const CellulaIconButtonSize(this.spacing);

  IconSize get iconSize {
    switch (this) {
      case CellulaIconButtonSize.small:
        return IconSize.small;
      case CellulaIconButtonSize.medium:
        return IconSize.medium;
      case CellulaIconButtonSize.large:
        return IconSize.large;
    }
  }
}

class CellulaIconButton extends StatelessWidget {
  final CellulaIconButtonSize cellulaIconButtonSize;
  final Color color;
  final IconAsset iconAsset;
  final String toolTip;
  final bool ignoreAccessibilitySize;
  final Function() onPressed;
  final EdgeInsetsGeometry? padding;

  const CellulaIconButton({
    required this.onPressed,
    required this.cellulaIconButtonSize,
    required this.color,
    required this.iconAsset,
    required this.toolTip,
    this.ignoreAccessibilitySize = false,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final iconButtonWidget = IconButton(
      padding: padding,
      onPressed: onPressed,
      hoverColor: Colors.transparent,
      highlightColor: color.withOpacity(0.16),
      splashRadius: cellulaIconButtonSize.spacing.spacing / 2,
      icon: CellulaIcon(
        iconAsset: iconAsset,
        size: cellulaIconButtonSize.iconSize,
        color: color,
      ),
      tooltip: toolTip,
    );

    return ignoreAccessibilitySize
        ? SizedBox(
            width: cellulaIconButtonSize.spacing.spacing,
            height: cellulaIconButtonSize.spacing.spacing,
            child: iconButtonWidget,
          )
        : iconButtonWidget;
  }
}
