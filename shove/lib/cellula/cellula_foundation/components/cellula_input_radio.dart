import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';

class CellulaInputRadio<T> extends StatelessWidget {
  final CellulaTokens cellulaTokens;
  final String? text;
  final bool enabled;
  final bool hasValidationError;
  final T value;
  final T groupValue;
  final Function(T? value) onChanged;

  const CellulaInputRadio({
    required this.cellulaTokens,
    required this.enabled,
    required this.hasValidationError,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.text,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        unselectedWidgetColor: hasValidationError
            ? cellulaTokens.danger.border
            : cellulaTokens.bg.interactive
                .getCellulaDisabledColorIfDisabled(enabled),
      ),
      child: RadioListTile<T>(
        title: CellulaText(
          text: text ?? '',
          color: cellulaTokens.content.defaultColor
              .getCellulaDisabledColorIfDisabled(enabled),
          fontVariant: CellulaFontLabel.regular.fontVariant,
        ),
        tileColor:
            cellulaTokens.bg.surface.getCellulaDisabledColorIfDisabled(enabled),
        activeColor: cellulaTokens.bg.interactive
            .getCellulaDisabledColorIfDisabled(enabled),
        value: value,
        groupValue: groupValue,
        dense: true,
        onChanged: enabled
            ? (value) {
                onChanged(value);
              }
            : null,
      ),
    );
  }
}
