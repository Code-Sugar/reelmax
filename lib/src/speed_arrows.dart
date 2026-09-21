import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A small directional pulse, running only while the speed gesture is held.
class SpeedArrows extends StatefulWidget {
  const SpeedArrows({super.key, required this.active});
  final bool active;

  @override
  State<SpeedArrows> createState() => _SpeedArrowsState();
}

class _SpeedArrowsState extends State<SpeedArrows>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  void sync() {
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      if (!animation.isAnimating) animation.repeat();
    } else {
      animation.stop();
      animation.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(covariant SpeedArrows oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 28,
      height: 20,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => Stack(
          children: [
            for (var i = 0; i < 3; i++)
              Positioned(
                left: i * 7.0,
                top: 2,
                child: Opacity(
                  opacity:
                      .3 +
                      .7 *
                          (1 +
                              math.cos(
                                animation.value * math.pi * 2 - i * 1.2,
                              )) /
                          2,
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
