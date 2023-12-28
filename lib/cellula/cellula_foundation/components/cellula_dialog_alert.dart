import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/components/cellula_button.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';

class CellulaDialogAlert extends StatelessWidget {
  final CellulaTokens cellulaTokens;
  final String title;
  final String text;
  final String? okButtonText;
  final String? cancelButtonText;
  final bool isInLoadingState;
  final Function()? onOkButtonClick;
  final Function()? onCancelButtonClick;

  const CellulaDialogAlert({
    required this.cellulaTokens,
    required this.title,
    required this.text,
    required this.okButtonText,
    required this.onOkButtonClick,
    this.isInLoadingState = false,
    this.onCancelButtonClick,
    this.cancelButtonText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    assert(
      (okButtonText != null && onOkButtonClick != null) ||
          (cancelButtonText != null && onCancelButtonClick != null),
      'You must provide either an ok button or a cancel button because a dialog without buttons is not allowed. Because i make the rules; kneel pleb!',
    );

    return AlertDialog(
      surfaceTintColor: cellulaTokens.bg.surface,
      title: CellulaText(
        text: title,
        fontVariant: CellulaFontHeading.xSmall.fontVariant,
        color: cellulaTokens.content.defaultColor,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CellulaBorderRadius.small.value),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: CellulaSpacing.x2.spacing,
        vertical: CellulaSpacing.x2.spacing,
      ),
      titlePadding: EdgeInsets.only(
        top: CellulaSpacing.x2.spacing,
        left: CellulaSpacing.x2.spacing,
        right: CellulaSpacing.x2.spacing,
      ),
      contentPadding: EdgeInsets.only(
        top: CellulaSpacing.x1.spacing,
        left: CellulaSpacing.x2.spacing,
        right: CellulaSpacing.x2.spacing,
      ),
      actionsPadding: EdgeInsets.only(
        top: CellulaSpacing.x3.spacing,
        bottom: CellulaSpacing.x2.spacing,
        left: CellulaSpacing.x2.spacing,
        right: CellulaSpacing.x2.spacing,
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowAlignment: OverflowBarAlignment.center,
      actionsOverflowButtonSpacing: CellulaSpacing.x1.spacing,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CellulaText(
            text: text,
            fontVariant: CellulaFontBody.largeRegular.fontVariant,
            color: cellulaTokens.content.defaultColor,
          ),
        ],
      ),
      actions: [
        if (cancelButtonText != null && onCancelButtonClick != null)
          Padding(
            padding: EdgeInsets.only(right: CellulaSpacing.x1.spacing),
            child: CellulaButton(
              buttonVariant: CellulaButtonVariant.ghost(
                cellulaTokens,
                CellulaButtonSize.medium,
              ),
              text: cancelButtonText!,
              onPressed: onCancelButtonClick!,
            ),
          ),
        if (okButtonText != null && onOkButtonClick != null)
          CellulaButton(
            buttonVariant: CellulaButtonVariant.danger(
              cellulaTokens,
              CellulaButtonSize.medium,
            ),
            text: okButtonText!,
            onPressed: onOkButtonClick!,
            isInLoadingState: isInLoadingState,
          ),
      ],
    );
  }
}
