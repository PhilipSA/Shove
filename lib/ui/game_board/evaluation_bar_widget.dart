import 'package:flutter/material.dart';
import 'package:shove/interactor/shove_game_interactor.dart';

class EvaluationBarWidget extends StatelessWidget {
  final ShoveGameEvaluationState shoveGameEvaluationState;

  const EvaluationBarWidget({
    super.key,
    required this.shoveGameEvaluationState,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.3;

    return ListenableBuilder(
      listenable: shoveGameEvaluationState,
      builder: (context, _) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: shoveGameEvaluationState.evaluation),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) =>
            CustomPaint(painter: _EvaluationBarPainter(value), child: child),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 30,
            minWidth: 30,
            maxHeight: maxHeight,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _EvaluationBarPainter extends CustomPainter {
  final double value;

  _EvaluationBarPainter(this.value);

  static final _whitePaint = Paint()..color = Colors.grey;
  static final _blackPaint = Paint()..color = Colors.black;

  @override
  void paint(Canvas canvas, Size size) {
    double whiteFraction = (value + 10) / 20;
    double blackFraction = 1 - whiteFraction;

    if (whiteFraction.isNaN) whiteFraction = 0.5;
    if (blackFraction.isNaN) blackFraction = 0.5;

    if (whiteFraction.isInfinite && blackFraction.isNegative) {
      whiteFraction = 1;
      blackFraction = 0;
    } else if (blackFraction.isInfinite && whiteFraction.isNegative) {
      whiteFraction = 0;
      blackFraction = 1;
    }

    // Draw white part
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        size.height * blackFraction,
        size.width,
        size.height * whiteFraction,
      ),
      _whitePaint,
    );

    // Draw black part
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * blackFraction),
      _blackPaint,
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
    textPainter.dispose();
  }

  @override
  bool shouldRepaint(_EvaluationBarPainter oldDelegate) =>
      oldDelegate.value != value;
}
