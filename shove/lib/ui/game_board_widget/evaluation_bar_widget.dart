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
    return CustomPaint(
      painter: _EvaluationBarPainter(currentEvalStateValue.evaluation),
      child: Container(
        height: 2000,
        width: 20,
      ), // Set the height of the bar
    );
  }
}

class _EvaluationBarPainter extends CustomPainter {
  final double value;

  _EvaluationBarPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final whitePaint = Paint()..color = Colors.grey;
    final blackPaint = Paint()..color = Colors.black;

    double whiteFraction =
        (value + 10) / 20; // Convert value to fraction for white
    double blackFraction = 1 - whiteFraction; // Remaining fraction for black

    // Draw white part
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * blackFraction, size.width,
          size.height * whiteFraction),
      whitePaint,
    );

    // Draw black part
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * blackFraction),
      blackPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Redraw whenever the widget is rebuilt
  }
}
