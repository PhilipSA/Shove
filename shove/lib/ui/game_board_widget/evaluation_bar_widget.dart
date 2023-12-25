import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      child: const SizedBox(
        height: 2000,
        width: 30,
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

    double whiteFraction = (value + 10) / 20;
    double blackFraction = 1 - whiteFraction;

    if (whiteFraction.isInfinite && blackFraction.isNegative) {
      whiteFraction = 1;
      blackFraction = 0;
    } else if (blackFraction.isInfinite && whiteFraction.isNegative) {
      whiteFraction = 0;
      blackFraction = 1;
    }

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

    // Draw the text
    final textSpan = TextSpan(
      text: value.toStringAsFixed(1),
      style: const TextStyle(color: Colors.white, fontSize: 12),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(minWidth: 0, maxWidth: size.width);

    // Positioning the text at the bottom center of the bar
    final xCenter = (size.width - textPainter.width) / 2;
    final yPosition = size.height - textPainter.height;

    textPainter.paint(canvas, Offset(xCenter, yPosition));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Redraw whenever the widget is rebuilt
  }
}
