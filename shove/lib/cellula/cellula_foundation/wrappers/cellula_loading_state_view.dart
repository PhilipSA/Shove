import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';

class CellulaLoadingStateView extends StatelessWidget {
  final CellulaTokens cellulaTokens;

  const CellulaLoadingStateView({required this.cellulaTokens, super.key});

  @override
  Widget build(BuildContext context) {
    final size = CellulaSpacing.x9.spacing;
    return Stack(
      children: [
        Positioned.fill(
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: CircularProgressIndicator(
                color: cellulaTokens.info.content,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
