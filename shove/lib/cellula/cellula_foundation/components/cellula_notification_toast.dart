import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_icon_button.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_icon.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/icon_asset.dart';

class CellulaNotificationToastVariant {
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final Color borderColor;
  final IconAsset iconAsset;

  CellulaNotificationToastVariant.info({required CellulaTokens cellulaTokens})
      : backgroundColor = cellulaTokens.info.bg,
        textColor = cellulaTokens.info.content,
        iconColor = cellulaTokens.info.contentMuted,
        borderColor = cellulaTokens.info.borderMuted,
        iconAsset = IconAsset.infoCircle;

  CellulaNotificationToastVariant.success({
    required CellulaTokens cellulaTokens,
  })  : backgroundColor = cellulaTokens.success.bg,
        textColor = cellulaTokens.success.content,
        iconColor = cellulaTokens.success.contentMuted,
        borderColor = cellulaTokens.success.borderMuted,
        iconAsset = IconAsset.check;

  CellulaNotificationToastVariant.warning({
    required CellulaTokens cellulaTokens,
  })  : backgroundColor = cellulaTokens.warning.bg,
        textColor = cellulaTokens.warning.content,
        iconColor = cellulaTokens.warning.contentMuted,
        borderColor = cellulaTokens.warning.borderMuted,
        iconAsset = IconAsset.warningCircle;

  CellulaNotificationToastVariant.danger({required CellulaTokens cellulaTokens})
      : backgroundColor = cellulaTokens.danger.bg,
        textColor = cellulaTokens.danger.content,
        iconColor = cellulaTokens.danger.contentMuted,
        borderColor = cellulaTokens.danger.borderMuted,
        iconAsset = IconAsset.warning;
}

class CellulaNotificationToast extends StatelessWidget {
  final CellulaNotificationToastVariant cellulaNotificationToastVariant;
  final String title;
  final String? text;
  final Function() onCloseClicked;

  const CellulaNotificationToast({
    required this.cellulaNotificationToastVariant,
    required this.title,
    required this.text,
    required this.onCloseClicked,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: cellulaNotificationToastVariant.backgroundColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cellulaNotificationToastVariant.borderColor),
        borderRadius: BorderRadius.circular(CellulaBorderRadius.small.value),
      ),
      elevation: CellulaElevation.floating.y,
      child: Padding(
        padding: EdgeInsets.all(CellulaSpacing.x2.spacing),
        child: _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CellulaIcon(
          iconAsset: cellulaNotificationToastVariant.iconAsset,
          size: IconSize.medium,
          color: cellulaNotificationToastVariant.iconColor,
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: CellulaSpacing.x2.spacing,
              right: CellulaSpacing.x2.spacing,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CellulaText(
                  text: title,
                  color: cellulaNotificationToastVariant.textColor,
                  fontVariant: CellulaFontLabel.largeSemiBold.fontVariant,
                ),
                if (text != null)
                  Padding(
                    padding: EdgeInsets.only(top: CellulaSpacing.x0_5.spacing),
                    child: CellulaText(
                      text: text!,
                      color: cellulaNotificationToastVariant.textColor,
                      fontVariant: CellulaFontLabel.regular.fontVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        CellulaIconButton(
          onPressed: onCloseClicked,
          cellulaIconButtonSize: CellulaIconButtonSize.medium,
          color: cellulaNotificationToastVariant.iconColor,
          iconAsset: IconAsset.x,
          ignoreAccessibilitySize: true,
          toolTip: 'null',
        ),
      ],
    );
  }
}
