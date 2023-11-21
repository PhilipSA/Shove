import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_icon_button.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/icon_asset.dart';

PreferredSizeWidget cellulaAppBar({
  required CellulaTokens cellulaTokens,
  required String? title,
  required Function() onNavBackPressed,
}) {
  return AppBar(
    title: title != null
        ? CellulaText(
            text: title,
            color: cellulaTokens.content.onAppNav,
            fontVariant: CellulaFontHeading.small.fontVariant,
          )
        : null,
    foregroundColor: cellulaTokens.content.onAppNav,
    backgroundColor: cellulaTokens.bg.surfaceDark,
    leading: CellulaIconButton(
      cellulaIconButtonSize: CellulaIconButtonSize.medium,
      color: cellulaTokens.content.onAppNav,
      iconAsset: IconAsset.chevronLeft,
      toolTip: 'Go back',
      onPressed: onNavBackPressed,
    ),
  );
}
