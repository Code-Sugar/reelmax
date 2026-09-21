import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'design.dart';

/// Keeps neighboring full-screen videos joined throughout a drag and its settle.
class VerticalSwipeController extends ChangeNotifier {
  VerticalSwipeController({
    required TickerProvider vsync,
    required this.onChanged,
    Duration duration = contentSwitchMotion,
    this.curve = arrive,
  }) : _animation = AnimationController(vsync: vsync, duration: duration) {
    _animation.addListener(_tick);
  }

  final ValueChanged<int> onChanged;
  final Curve curve;
  final AnimationController _animation;
  double offset = 0;
  int direction = 1;
  bool dragging = false, settling = false, _disposed = false;
  double _from = 0, _to = 0;

  bool get active => dragging || settling;

  void start() {
    if (settling) return;
    dragging = true;
    notifyListeners();
  }

  void update(DragUpdateDetails details, double height) {
    if (settling) return;
    dragging = true;
    // The only boundary is a whole viewport, never a fixed pixel distance.
    offset = (offset + details.delta.dy).clamp(-height, height);
    if (offset != 0) direction = offset < 0 ? 1 : -1;
    notifyListeners();
  }

  void end(DragEndDetails details, double height) {
    if (settling) return;
    final velocity = details.primaryVelocity ?? 0;
    final fling = velocity.abs() >= 650;
    final followsDrag = velocity == 0 || velocity.sign == offset.sign;
    final commit =
        offset != 0 &&
        (fling ? followsDrag : offset.abs() >= math.min(62, height * .15));
    _settle(commit ? -direction * height : 0, commit: commit);
  }

  void cancel() {
    if (dragging && !settling) _settle(0, commit: false);
  }

  void advance(int step, double height) {
    if (active) return;
    direction = step;
    _settle(-direction * height, commit: true);
  }

  void _tick() {
    offset = _from + (_to - _from) * curve.transform(_animation.value);
    notifyListeners();
  }

  Future<void> _settle(double destination, {required bool commit}) async {
    dragging = false;
    settling = true;
    _from = offset;
    _to = destination;
    notifyListeners();
    try {
      await _animation.forward(from: 0).orCancel;
      if (_disposed) return;
      if (commit) onChanged(direction);
      offset = 0;
      settling = false;
      notifyListeners();
    } on TickerCanceled {
      // Leaving a page can dispose it during its settling animation.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _animation.dispose();
    super.dispose();
  }
}
