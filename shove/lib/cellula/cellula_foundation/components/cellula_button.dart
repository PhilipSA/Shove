import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_icon.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/icon_asset.dart';

class CellulaButtonVariant {
  final CellulaButtonSize buttonSize;
  final Color backgroundColor;
  final Color? onPressColor;
  final Color textColor;
  final Color? borderColor;
  final CellulaButtonType buttonType;

  CellulaFontVariant getFontVariant() {
    switch (buttonSize) {
      case CellulaButtonSize.xSmall:
        {
          return CellulaFontLabel.smallSemiBold.fontVariant;
        }
      case CellulaButtonSize.small:
        {
          return CellulaFontLabel.semiBold.fontVariant;
        }
      case CellulaButtonSize.medium:
        {
          return CellulaFontLabel.semiBold.fontVariant;
        }
      case CellulaButtonSize.large:
        {
          return CellulaFontLabel.largeSemiBold.fontVariant;
        }
      case CellulaButtonSize.xLarge:
        {
          return CellulaFontLabel.largeSemiBold.fontVariant;
        }
    }
  }

  CellulaButtonVariant.primary(
    CellulaTokens cellulaTokens,
    this.buttonSize, {
    this.borderColor,
  })  : backgroundColor = cellulaTokens.bg.interactive,
        onPressColor = cellulaTokens.bg.interactiveActive,
        textColor = cellulaTokens.content.onInteractive,
        buttonType = CellulaButtonType.primary;

  CellulaButtonVariant.secondary(CellulaTokens cellulaTokens, this.buttonSize)
      : backgroundColor = const Color.fromARGB(0, 0, 0, 0),
        onPressColor = cellulaTokens.bg.interactiveMutedActive,
        textColor = cellulaTokens.content.interactive,
        borderColor = cellulaTokens.border.interactive,
        buttonType = CellulaButtonType.secondary;

  CellulaButtonVariant.ghost(
    CellulaTokens cellulaTokens,
    this.buttonSize, {
    this.borderColor,
  })  : backgroundColor = const Color.fromARGB(0, 0, 0, 0),
        onPressColor = cellulaTokens.bg.interactiveMutedActive,
        textColor = cellulaTokens.content.interactive,
        buttonType = CellulaButtonType.ghost;

  CellulaButtonVariant.danger(
    CellulaTokens cellulaTokens,
    this.buttonSize, {
    this.borderColor,
  })  : backgroundColor = cellulaTokens.danger.bg,
        onPressColor = cellulaTokens.danger.bgActive,
        textColor = cellulaTokens.danger.content,
        buttonType = CellulaButtonType.danger;

  EdgeInsetsGeometry padding(bool hasLeadingIcon, bool hasTrailingIcon) {
    final leadingLeftIconFactor =
        hasLeadingIcon ? CellulaSpacing.x1.spacing : 0;
    final trailingRightIconFactor =
        hasTrailingIcon ? CellulaSpacing.x1.spacing : 0;

    switch (buttonSize) {
      case CellulaButtonSize.xLarge:
        return EdgeInsets.fromLTRB(
          CellulaSpacing.x5.spacing - leadingLeftIconFactor,
          CellulaSpacing.x2_5.spacing,
          CellulaSpacing.x5.spacing - trailingRightIconFactor,
          CellulaSpacing.x2_5.spacing,
        );
      case CellulaButtonSize.large:
        return EdgeInsets.fromLTRB(
          CellulaSpacing.x4.spacing - leadingLeftIconFactor,
          CellulaSpacing.x2.spacing,
          CellulaSpacing.x4.spacing - trailingRightIconFactor,
          CellulaSpacing.x2.spacing,
        );
      case CellulaButtonSize.medium:
        return EdgeInsets.fromLTRB(
          CellulaSpacing.x4.spacing - leadingLeftIconFactor,
          CellulaSpacing.x1_5.spacing,
          CellulaSpacing.x4.spacing - trailingRightIconFactor,
          CellulaSpacing.x1_5.spacing,
        );
      case CellulaButtonSize.small:
        return EdgeInsets.fromLTRB(
          CellulaSpacing.x3.spacing - leadingLeftIconFactor,
          CellulaSpacing.x1.spacing,
          CellulaSpacing.x3.spacing - trailingRightIconFactor,
          CellulaSpacing.x1.spacing,
        );
      case CellulaButtonSize.xSmall:
        return EdgeInsets.fromLTRB(
          CellulaSpacing.x2.spacing - leadingLeftIconFactor,
          CellulaSpacing.x0_5.spacing,
          CellulaSpacing.x2.spacing - trailingRightIconFactor,
          CellulaSpacing.x0_5.spacing,
        );
    }
  }

  CellulaSpacing minimumHeight() {
    switch (buttonSize) {
      case CellulaButtonSize.xLarge:
        return CellulaSpacing.x8;
      case CellulaButtonSize.large:
        return CellulaSpacing.x7;
      case CellulaButtonSize.medium:
        return CellulaSpacing.x6;
      case CellulaButtonSize.small:
        return CellulaSpacing.x5;
      case CellulaButtonSize.xSmall:
        return CellulaSpacing.x4;
    }
  }
}

enum CellulaButtonType { primary, secondary, ghost, danger }

enum CellulaButtonSize { xLarge, large, medium, small, xSmall }

class CellulaButton extends StatelessWidget {
  final CellulaButtonVariant buttonVariant;
  final String text;
  final IconAsset? iconAsset;
  final Function() onPressed;
  final bool isLeadingIcon;
  final bool enabled;
  final bool isInLoadingState;
  final MainAxisSize mainAxisSize;

  bool get isEnabled => enabled && !isInLoadingState;

  bool get hasLeadingIcon => iconAsset != null && isLeadingIcon;

  bool get hasTrailingIcon => iconAsset != null && !isLeadingIcon;

  const CellulaButton({
    required this.buttonVariant,
    required this.text,
    required this.onPressed,
    super.key,
    this.isLeadingIcon = false,
    this.enabled = true,
    this.isInLoadingState = false,
    this.mainAxisSize = MainAxisSize.min,
    this.iconAsset,
  });

  Widget _getButtonTextWidget() {
    return CellulaText(
      text: text,
      color:
          buttonVariant.textColor.getCellulaDisabledColorIfDisabled(isEnabled),
      fontVariant: buttonVariant.getFontVariant(),
    );
  }

  Widget _iconView(IconAsset icon) {
    return CellulaIcon(
      iconAsset: icon,
      size: IconSize.medium,
      color:
          buttonVariant.textColor.getCellulaDisabledColorIfDisabled(isEnabled),
    );
  }

  Widget _buttonContent() {
    final rowChildren = <Widget>[
      Visibility(
        visible: isInLoadingState,
        child: Padding(
          padding: EdgeInsets.only(right: CellulaSpacing.x1.spacing),
          child: SizedBox(
            width: CellulaSpacing.x2_5.spacing,
            height: CellulaSpacing.x2_5.spacing,
            child: CircularProgressIndicator(
              color: buttonVariant.textColor,
              strokeWidth: 2.0,
            ),
          ),
        ),
      ),
    ];

    if (hasLeadingIcon && !isInLoadingState) {
      rowChildren.add(
        Padding(
          padding: EdgeInsets.only(right: CellulaSpacing.x1.spacing),
          child: _iconView(iconAsset!),
        ),
      );
    }

    rowChildren.add(Flexible(child: _getButtonTextWidget()));

    if (hasTrailingIcon && !isInLoadingState) {
      rowChildren.add(
        Padding(
          padding: EdgeInsets.only(left: CellulaSpacing.x1.spacing),
          child: _iconView(iconAsset!),
        ),
      );
    }

    return Row(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: rowChildren,
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ButtonStyle(
      backgroundColor: MaterialStateProperty.all(
        buttonVariant.backgroundColor
            .getCellulaDisabledColorIfDisabled(isEnabled),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CellulaBorderRadius.circle.value),
          side: buttonVariant.buttonType == CellulaButtonType.secondary
              ? BorderSide(
                  color: buttonVariant.borderColor
                          ?.getCellulaDisabledColorIfDisabled(isEnabled) ??
                      buttonVariant.backgroundColor
                          .getCellulaDisabledColorIfDisabled(isEnabled),
                  width: 2.0,
                )
              : BorderSide.none,
        ),
      ),
      overlayColor: MaterialStateProperty.resolveWith<Color?>(
          (Set<MaterialState> states) {
        if (states.contains(MaterialState.pressed)) {
          return buttonVariant.onPressColor;
        }
        return null; // Defer to the widget's default.
      }),
      padding: MaterialStateProperty.all(
        buttonVariant.padding(hasLeadingIcon, hasTrailingIcon),
      ),
      minimumSize: MaterialStateProperty.all<Size>(
        Size(0, buttonVariant.minimumHeight().spacing),
      ),
    );

    return switch (buttonVariant.buttonType) {
      CellulaButtonType.primary => FilledButton(
          style: buttonStyle,
          onPressed: isEnabled ? onPressed : null,
          child: _buttonContent(),
        ),
      CellulaButtonType.secondary => TextButton(
          style: buttonStyle,
          onPressed: isEnabled ? onPressed : null,
          child: _buttonContent(),
        ),
      CellulaButtonType.ghost => TextButton(
          style: buttonStyle,
          onPressed: isEnabled ? onPressed : null,
          child: _buttonContent(),
        ),
      CellulaButtonType.danger => FilledButton(
          style: buttonStyle,
          onPressed: isEnabled ? onPressed : null,
          child: _buttonContent(),
        ),
    };
  }
}
