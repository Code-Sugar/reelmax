import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'design.dart';

const startupBackground = Color(0xff09090b);

Future<void> prepareStartup(BuildContext context) async {
  // Warm only the first visible poster. The home screen initializes its own
  // video underneath the cover; startup never depends on network or playback.
  await precacheImage(
    const AssetImage('assets/battle-of-two-cities.png'),
    context,
  );
}

/// Mounted once inside the phone stage. Backgrounding or changing tabs does
/// not replay it, and the home state survives removal of the visual cover.
class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.child,
    this.prepare = prepareStartup,
  });
  final Widget child;
  final Future<void> Function(BuildContext) prepare;
  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate>
    with TickerProviderStateMixin {
  late final entrance =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) revealIfReady();
      });
  late final exit =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 360),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => finished = true);
        }
      });
  Timer? deadline;
  bool started = false,
      ready = false,
      leaving = false,
      finished = false,
      reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion) {
      entrance.value = 1;
    } else {
      entrance.forward();
    }
    // A missing or slow local asset must never trap someone on the splash.
    deadline = Timer(const Duration(seconds: 2), prepared);
    unawaited(warmup());
  }

  Future<void> warmup() async {
    try {
      await widget.prepare(context);
    } catch (error) {
      debugPrint('Startup preload skipped: $error');
    }
    if (mounted) prepared();
  }

  void prepared() {
    if (!mounted || ready) return;
    deadline?.cancel();
    ready = true;
    revealIfReady();
  }

  void revealIfReady() {
    if (!mounted || !ready || !entrance.isCompleted || leaving) return;
    leaving = true;
    if (reducedMotion) {
      setState(() => finished = true);
    } else {
      exit.forward();
    }
  }

  @override
  void dispose() {
    deadline?.cancel();
    entrance.dispose();
    exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeFocus(
        excluding: !finished,
        child: ExcludeSemantics(
          excluding: !finished,
          child: IgnorePointer(ignoring: !finished, child: widget.child),
        ),
      ),
      if (!finished)
        Positioned.fill(
          child: FadeTransition(
            opacity: ReverseAnimation(
              CurvedAnimation(parent: exit, curve: Curves.easeOut),
            ),
            child: StartupArtwork(animation: entrance),
          ),
        ),
    ],
  );
}

/// The first frame matches the native launch mark: same dark canvas, 80 px
/// circle and centered position. The mark rises as the wordmark appears.
class StartupArtwork extends StatelessWidget {
  const StartupArtwork({
    super.key,
    this.animation = const AlwaysStoppedAnimation(1),
  });
  final Animation<double> animation;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Reel Max',
    container: true,
    image: true,
    child: ExcludeSemantics(
      child: Material(
        color: startupBackground,
        key: const ValueKey('startup-screen'),
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            final lift = const Interval(
              0,
              .72,
              curve: Curves.easeOutCubic,
            ).transform(t);
            final title = const Interval(
              .16,
              .78,
              curve: Curves.easeOutCubic,
            ).transform(t);
            final caption = const Interval(
              .4,
              1,
              curve: Curves.easeOut,
            ).transform(t);
            return LayoutBuilder(
              builder: (context, bounds) {
                final center = bounds.maxHeight / 2;
                final compact = bounds.maxHeight < 540;
                final shift = compact ? 52.0 : 70.0;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: lift,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(.12, -.12),
                            radius: .82,
                            colors: [
                              Color(0xff26342b),
                              Color(0xff151d18),
                              startupBackground,
                            ],
                            stops: [0, .42, 1],
                          ),
                        ),
                      ),
                    ),
                    // A restrained glow, shaped like light crossing a cinema lens.
                    Positioned(
                      left: -bounds.maxWidth * .3,
                      right: -bounds.maxWidth * .3,
                      top: center - 180,
                      height: 280,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: lift * .35,
                          child: Transform.rotate(
                            angle: -.34,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0x25cee0c4),
                                    Color(0x00cee0c4),
                                  ],
                                  radius: .65,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: center - 40 - shift * lift,
                      left: 0,
                      right: 0,
                      child: const Center(child: ReelLaunchMark()),
                    ),
                    Positioned(
                      top: center + (compact ? 14 : 24) + (1 - title) * 10,
                      left: 28,
                      right: 28,
                      child: Opacity(
                        opacity: title,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Reel Max',
                            style: type(
                              compact ? 43 : 49,
                              weight: 800,
                              slant: -8,
                              spacing: -2.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: center + (compact ? 76 : 91),
                      left: 24,
                      right: 24,
                      child: Opacity(
                        opacity: caption,
                        child: Text(
                          'SHORT STORIES. BIG FEELINGS.',
                          textAlign: TextAlign.center,
                          style: type(
                            9,
                            weight: 450,
                            spacing: 2.05,
                            color: const Color(0xff9ba99d),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom:
                          math.max(MediaQuery.paddingOf(context).bottom, 16) +
                          34,
                      left: 0,
                      right: 0,
                      child: Opacity(
                        opacity: caption * .6,
                        child: Center(
                          child: Container(
                            width: 28,
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0xff98a498),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    ),
  );
}

class ReelLaunchMark extends StatelessWidget {
  const ReelLaunchMark({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 80,
    child: CustomPaint(painter: _LaunchMarkPainter()),
  );
}

class _LaunchMarkPainter extends CustomPainter {
  const _LaunchMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 80, size.height / 80);
    const rect = Rect.fromLTWH(1, 1, 78, 78);
    canvas.drawCircle(
      const Offset(40, 40),
      39,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff546159), Color(0xff29352e), Color(0xff19251f)],
          stops: [0, .36, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      const Offset(40, 40),
      38.5,
      Paint()
        ..color = const Color(0xff819087)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    canvas.drawArc(
      rect.deflate(.8),
      -math.pi * .94,
      math.pi * .87,
      false,
      Paint()
        ..color = const Color(0xffc6d2c9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    final play = Path()
      ..moveTo(34, 25)
      ..cubicTo(32, 24, 30, 25, 30, 28)
      ..lineTo(30, 52)
      ..cubicTo(30, 55, 32, 56, 34, 55)
      ..lineTo(56, 43)
      ..cubicTo(58, 41, 58, 39, 56, 37)
      ..close();
    canvas.drawPath(play, Paint()..color = ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LaunchMarkPainter oldDelegate) => false;
}
