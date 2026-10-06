import 'package:flutter/foundation.dart';

/// The puzzles solved so far in this session.
class PuzzleProgress extends ChangeNotifier {
  final _solved = <int>{};

  bool isSolved(int index) => _solved.contains(index);

  int get solvedCount => _solved.length;

  void markSolved(int index) {
    if (_solved.add(index)) notifyListeners();
  }
}
