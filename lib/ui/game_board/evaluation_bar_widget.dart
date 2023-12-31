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

class _EvaluationBarWidgetState extends State<EvaluationBarWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _updateAnimation(0.0);
  }

  _updateAnimation(double? evaluation) {
    _animation = Tween<double>(
      begin: _animation?.value ?? 0.0,
      end: evaluation,
    ).animate(_controller!)
      ..addListener(() {
        setState(() {});
      });

    _controller!
      ..reset() // Reset the animation
      ..forward(); // Start the animation
  }

  void _listenForAnimationChanges() {
    final currentEvalStateValue = context.watch<ShoveGameEvaluationState>();

    if ((_animation?.value ?? 0.0) != currentEvalStateValue.evaluation) {
      _updateAnimation(currentEvalStateValue.evaluation);
    }
  }

  @override
  Widget build(BuildContext context) {
    _listenForAnimationChanges();
    return CustomPaint(
      painter: _EvaluationBarPainter(_animation?.value ?? 0.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 30,
          minWidth: 30,
          maxHeight: MediaQuery.of(context).size.height * 0.3,
        ),
        child: Container(),
      ),
    );
  }

  @override
  void dispose() {
    _controller
        ?.dispose(); // Dispose the controller when the widget is disposed
    super.dispose();
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
