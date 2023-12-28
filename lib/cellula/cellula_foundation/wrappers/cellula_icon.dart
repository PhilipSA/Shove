import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/icon_asset.dart';

enum IconSize {
  xSmall(value: CellulaSpacing.x2),
  small(value: CellulaSpacing.x2_5),
  medium(value: CellulaSpacing.x3),
  large(value: CellulaSpacing.x4),
  avatarSmall(value: CellulaSpacing.x4),
  avatarMedium(value: CellulaSpacing.x5),
  avatarLarge(value: CellulaSpacing.x6);

  final CellulaSpacing value;

  double get rawValue => (value.spacing);

  const IconSize({
    required this.value,
  });
}

class CellulaIcon extends StatelessWidget {
  final IconAsset? iconAsset;
  final String? iconUrl;
  final IconSize size;
  final Color? color;
  final Color? borderColor;
  final Color? backgroundColor;
  final bool isCircle;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;

  const CellulaIcon({
    required this.iconAsset,
    required this.size,
    required this.color,
    this.iconUrl,
    super.key,
    this.borderColor,
    this.backgroundColor,
    this.isCircle = false,
    this.padding,
    this.borderRadius,
  });

  ColorFilter iconColorFilter(Color color) {
    return ColorFilter.mode(color, BlendMode.srcIn);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      iconAsset != null || iconUrl != null,
      'You must either provide an iconAsset or iconUrl. Otherwise it will not be much of an icon will it?',
    );

    final asset = iconAsset != null
        ? SvgPicture.asset(
            iconAsset!.iconPath,
            width: size.rawValue,
            height: size.rawValue,
            colorFilter: color != null ? iconColorFilter(color!) : null,
          )
        : Image.network(
            iconUrl!,
            width: size.rawValue,
            height: size.rawValue,
            errorBuilder: (context, error, stackTrace) => CellulaIcon(
              iconAsset: IconAsset.fileError,
              size: size,
              color: null,
            ),
          );

    final automaticBorderRadius = isCircle
        ? BorderRadius.circular(
            CellulaBorderRadius.circle.value,
          )
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        borderRadius: borderRadius ?? automaticBorderRadius,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(CellulaSpacing.x0_25.spacing),
        child: asset,
      ),
    );
  }
}
