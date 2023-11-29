import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';
import 'package:shove/interactor/shove_game_interactor.dart';

class EvaluationBarWidget extends StatefulWidget {
  final ShoveGameEvaluationState shoveGameEvaluationState;

  const EvaluationBarWidget(
      {super.key, required this.shoveGameEvaluationState});

  @override
  createState() => _EvaluationBarWidgetState();
}

class _EvaluationBarWidgetState extends State<EvaluationBarWidget> {
  @override
  Widget build(BuildContext context) {
    final currentEvalStateValue = context.watch<ShoveGameEvaluationState>();

    return CellulaText(
        text: currentEvalStateValue.evaluation.toStringAsFixed(2),
        color: CellulaTokens.none().content.defaultColor,
        fontVariant: CellulaFontHeading.xSmall.fontVariant);
  }
}
