import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_icon_button.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_icon.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/icon_asset.dart';

class CellulaNotificationAlertVariant {
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final Color borderColor;
  final IconAsset iconAsset;

  CellulaNotificationAlertVariant.info({required CellulaTokens cellulaTokens})
      : backgroundColor = cellulaTokens.info.bg,
        textColor = cellulaTokens.info.content,
        iconColor = cellulaTokens.info.contentMuted,
        borderColor = cellulaTokens.info.borderMuted,
        iconAsset = IconAsset.infoCircle;

  CellulaNotificationAlertVariant.success({
    required CellulaTokens cellulaTokens,
  })  : backgroundColor = cellulaTokens.success.bg,
        textColor = cellulaTokens.success.content,
        iconColor = cellulaTokens.success.contentMuted,
        borderColor = cellulaTokens.success.borderMuted,
        iconAsset = IconAsset.check;

  CellulaNotificationAlertVariant.warning({
    required CellulaTokens cellulaTokens,
  })  : backgroundColor = cellulaTokens.warning.bg,
        textColor = cellulaTokens.warning.content,
        iconColor = cellulaTokens.warning.contentMuted,
        borderColor = cellulaTokens.warning.borderMuted,
        iconAsset = IconAsset.warningCircle;

  CellulaNotificationAlertVariant.danger({required CellulaTokens cellulaTokens})
      : backgroundColor = cellulaTokens.danger.bg,
        textColor = cellulaTokens.danger.content,
        iconColor = cellulaTokens.danger.contentMuted,
        borderColor = cellulaTokens.danger.borderMuted,
        iconAsset = IconAsset.warning;
}

class CellulaNotificationAlert extends StatelessWidget {
  final CellulaNotificationAlertVariant cellulaNotificationAlertVariant;
  final String text;
  final Function()? onCloseClicked;

  const CellulaNotificationAlert({
    required this.cellulaNotificationAlertVariant,
    required this.text,
    this.onCloseClicked,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shadowColor: Colors.transparent,
      color: cellulaNotificationAlertVariant.backgroundColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cellulaNotificationAlertVariant.borderColor),
        borderRadius: BorderRadius.circular(CellulaBorderRadius.small.value),
      ),
      child: Padding(
        padding: EdgeInsets.all(CellulaSpacing.x1.spacing),
        child: _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CellulaIcon(
          iconAsset: cellulaNotificationAlertVariant.iconAsset,
          size: IconSize.small,
          color: cellulaNotificationAlertVariant.iconColor,
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: CellulaSpacing.x1.spacing,
              right: CellulaSpacing.x1.spacing,
            ),
            child: CellulaText(
              text: text,
              color: cellulaNotificationAlertVariant.textColor,
              fontVariant: CellulaFontLabel.regular.fontVariant,
            ),
          ),
        ),
        if (onCloseClicked != null)
          CellulaIconButton(
            onPressed: onCloseClicked!,
            cellulaIconButtonSize: CellulaIconButtonSize.medium,
            color: cellulaNotificationAlertVariant.iconColor,
            iconAsset: IconAsset.x,
            ignoreAccessibilitySize: true,
            toolTip: 'null',
          ),
      ],
    );
  }
}
