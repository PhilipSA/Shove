import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_icon.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_shimmer.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/icon_asset.dart';

class CellulaIconTextPair extends StatelessWidget {
  final String text;
  final Color color;
  final CellulaFontVariant fontVariant;
  final bool hasTrailingIcon;
  final IconAsset iconAsset;
  final bool showLoadingState;

  const CellulaIconTextPair({
    required this.text,
    required this.color,
    required this.fontVariant,
    required this.iconAsset,
    this.hasTrailingIcon = false,
    super.key,
    this.showLoadingState = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = _shimmerLoadingWrapper(
      CellulaIcon(
        iconAsset: iconAsset,
        size: IconSize.medium,
        color: color,
      ),
      Size(IconSize.medium.rawValue, IconSize.medium.rawValue),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hasTrailingIcon)
          Padding(
            padding: EdgeInsets.only(right: CellulaSpacing.x1.spacing),
            child: iconWidget,
          ),
        Flexible(
          child: _shimmerLoadingWrapper(
            CellulaText(
              text: text,
              color: color,
              fontVariant: fontVariant,
            ),
            const Size(200, 20),
          ),
        ),
        if (hasTrailingIcon)
          Padding(
            padding: EdgeInsets.only(left: CellulaSpacing.x1.spacing),
            child: iconWidget,
          ),
      ],
    );
  }

  Widget _shimmerLoadingWrapper(Widget child, Size size) {
    return CellulaShimmerLoading(
      isLoading: showLoadingState,
      shimmerBoxSize: size,
      child: child,
    );
  }
}
