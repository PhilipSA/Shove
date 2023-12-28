import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';
import 'package:shove/cellula/cellula_foundation/cellula_tokens.dart';
import 'package:shove/cellula/cellula_foundation/wrappers/cellula_text.dart';

class TimerWidget extends StatefulWidget {
  const TimerWidget({super.key});

  @override
  createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  late final Stopwatch _stopwatch;

  late final Timer _timer;

  String _timerText = '00:00';

  String formatTime(int milliseconds) {
    var seconds = milliseconds ~/ 1000;
    var minutes = seconds ~/ 60;
    return '${(minutes % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _stopwatch.start();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timerText = formatTime(_stopwatch.elapsedMilliseconds);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return CellulaText(
        text: _timerText,
        color: CellulaTokens.none().content.defaultColor,
        fontVariant: CellulaFontHeading.xSmall.fontVariant);
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _timer.cancel();
    super.dispose();
  }
}
