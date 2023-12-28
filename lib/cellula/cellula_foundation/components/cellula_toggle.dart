import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_icon.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/icon_asset.dart';

class CellulaToggle extends StatelessWidget {
  final CellulaTokens cellulaTokens;
  final String? title;
  final IconAsset? leadingIcon;
  final bool dense;
  final bool value;
  final Function(bool) onChanged;

  const CellulaToggle({
    required this.cellulaTokens,
    required this.value,
    required this.onChanged,
    required this.dense,
    super.key,
    this.title,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: title != null
          ? CellulaText(
              text: title!,
              color: cellulaTokens.content.defaultColor,
              fontVariant: CellulaFontLabel.semiBold.fontVariant,
            )
          : null,
      value: value,
      onChanged: onChanged,
      dense: dense,
      activeTrackColor: cellulaTokens.bg.interactive,
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return cellulaTokens.bg.surface;
        }
        return null;
      }),
      thumbIcon: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return Icon(
            Icons.check_rounded,
            color: cellulaTokens.bg.interactive,
            size: CellulaSpacing.x2_5.spacing,
          );
        }
        return null;
      }),
      secondary: leadingIcon != null
          ? CellulaIcon(
              iconAsset: leadingIcon,
              size: IconSize.medium,
              color: cellulaTokens.content.defaultColor,
            )
          : null,
    );
  }
}
