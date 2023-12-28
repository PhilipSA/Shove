import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_icon.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/icon_asset.dart';

class CellulaValidationErrorText extends StatelessWidget {
  final CellulaTokens cellulaTokens;
  final String errorText;

  const CellulaValidationErrorText({
    required this.cellulaTokens,
    required this.errorText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CellulaIcon(
          iconAsset: IconAsset.infoCircle,
          size: IconSize.small,
          color: cellulaTokens.danger.contentMuted,
        ),
        Flexible(
          child: Padding(
            padding: EdgeInsets.only(left: CellulaSpacing.x0_5.spacing),
            child: CellulaText(
              text: errorText,
              color: cellulaTokens.danger.contentMuted,
              fontVariant: CellulaFontLabel.regular.fontVariant,
            ),
          ),
        ),
      ],
    );
  }
}
