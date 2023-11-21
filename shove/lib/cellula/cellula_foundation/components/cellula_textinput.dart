import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/shared_helpers/cellula_validation_error_text.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';

class CellulaTextInput extends StatelessWidget {
  final CellulaTokens cellulaTokens;
  final String placeholderText;
  final int? maxLength;
  final TextEditingController? textEditingController;
  final String? label;
  final bool enabled;
  final bool isRequired;
  final String? errorText;
  final bool isMultiline;
  final Function(String) onChanged;

  const CellulaTextInput({
    required this.cellulaTokens,
    required this.placeholderText,
    required this.onChanged,
    this.textEditingController,
    this.label,
    this.maxLength,
    this.enabled = true,
    this.isRequired = false,
    this.errorText,
    this.isMultiline = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: CellulaSpacing.x6.spacing,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: EdgeInsets.only(
                left: CellulaSpacing.x1.spacing,
                bottom: CellulaSpacing.x0_5.spacing,
              ),
              child: CellulaText(
                text: label! + (isRequired ? ' *' : ''),
                color: cellulaTokens.content.defaultColor,
                fontVariant: CellulaFontLabel.semiBold.fontVariant,
              ),
            ),
          TextField(
            decoration: InputDecoration(
              fillColor: enabled
                  ? cellulaTokens.bg.surface
                  : cellulaTokens.bg.readOnly,
              filled: true,
              floatingLabelBehavior: FloatingLabelBehavior.never,
              label: CellulaText(
                text: placeholderText,
                color: cellulaTokens.content.placeholder,
                fontVariant: CellulaFontLabel.regular.fontVariant,
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: errorText == null
                      ? cellulaTokens.border.interactive
                      : cellulaTokens.danger.border,
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(CellulaBorderRadius.small.value),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: errorText == null
                      ? cellulaTokens.border.input
                      : cellulaTokens.danger.border,
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(CellulaBorderRadius.small.value),
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.transparent),
                borderRadius: BorderRadius.all(
                  Radius.circular(CellulaBorderRadius.small.value),
                ),
              ),
              counterStyle: const TextStyle(
                height: double.minPositive,
              ),
              counterText: '',
              error: errorText != null
                  ? CellulaValidationErrorText(
                      cellulaTokens: cellulaTokens,
                      errorText: errorText!,
                    )
                  : null,
            ),
            onChanged: onChanged,
            maxLength: maxLength,
            enabled: enabled,
            controller: textEditingController,
            style: const TextStyle(height: 1.0),
            keyboardType: isMultiline ? TextInputType.multiline : null,
            maxLines: isMultiline ? null : 1,
          ),
        ],
      ),
    );
  }
}
