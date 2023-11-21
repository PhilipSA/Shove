import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';

class CellulaInputCheckbox extends StatelessWidget {
  final CellulaTokens cellulaTokens;
  final bool value;
  final bool enabled;
  final String? title;
  final bool hasValidationError;
  final Function(bool?) onChanged;

  const CellulaInputCheckbox({
    required this.cellulaTokens,
    required this.value,
    required this.enabled,
    required this.title,
    required this.hasValidationError,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      enabled: enabled,
      activeColor: cellulaTokens.bg.interactive
          .getCellulaDisabledColorIfDisabled(enabled),
      checkColor: cellulaTokens.content.onInteractive
          .getCellulaDisabledColorIfDisabled(enabled),
      tileColor:
          cellulaTokens.bg.surface.getCellulaDisabledColorIfDisabled(enabled),
      dense: true,
      contentPadding: EdgeInsets.zero,
      isError: hasValidationError,
      title: CellulaText(
        text: title ?? '',
        color: cellulaTokens.content.defaultColor
            .getCellulaDisabledColorIfDisabled(enabled),
        fontVariant: CellulaFontLabel.regular.fontVariant,
      ),
      onChanged: enabled
          ? (newValue) {
              onChanged(newValue);
            }
          : null,
    );
  }
}
