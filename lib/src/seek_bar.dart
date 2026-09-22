import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class EpisodeSeekBar extends StatefulWidget {
  const EpisodeSeekBar({
    super.key,
    required this.controller,
    required this.onScrubbing,
  });
  final VideoPlayerController controller;
  final ValueChanged<bool> onScrubbing;
  @override
  State<EpisodeSeekBar> createState() => _EpisodeSeekBarState();
}

class _EpisodeSeekBarState extends State<EpisodeSeekBar> {
  double? fraction;
  bool resume = false, finishing = false;
  Future<void> pending = Future.value();
  Duration get target => Duration(
    milliseconds:
        (widget.controller.value.duration.inMilliseconds * (fraction ?? 0))
            .round(),
  );

  void begin(double x, double width) {
    if (finishing) return;
    resume = widget.controller.value.isPlaying;
    widget.onScrubbing(true);
    pending = widget.controller.pause();
    move(x, width);
  }

  void move(double x, double width) {
    if (finishing) return;
    setState(() => fraction = (x / width).clamp(0, 1));
  }

  Future<void> finish() async {
    if (fraction == null || finishing) return;
    finishing = true;
    final position = target;
    await pending;
    if (!mounted) return;
    await widget.controller.seekTo(position);
    if (!mounted) return;
    if (resume) await widget.controller.play();
    if (!mounted) return;
    setState(() {
      fraction = null;
      finishing = false;
    });
    widget.onScrubbing(false);
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: widget.controller,
    builder: (_, value, _) => LayoutBuilder(
      builder: (_, constraints) {
        final dragging = fraction != null;
        final duration = value.duration.inMilliseconds;
        final progress =
            fraction ??
            (duration <= 0 ? 0.0 : value.position.inMilliseconds / duration)
                .clamp(0.0, 1.0);
        final buffered = duration <= 0 || value.buffered.isEmpty
            ? 0.0
            : (value.buffered.last.end.inMilliseconds / duration).clamp(
                0.0,
                1.0,
              );
        return SizedBox(
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                key: const ValueKey('seek-touch-layer'),
                child: GestureDetector(
                  key: const ValueKey('episode-seek-bar'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (d) =>
                      begin(d.localPosition.dx, constraints.maxWidth),
                  onHorizontalDragUpdate: (d) =>
                      move(d.localPosition.dx, constraints.maxWidth),
                  onHorizontalDragEnd: (_) => finish(),
                  onHorizontalDragCancel: finish,
                  onTapUp: (d) {
                    begin(d.localPosition.dx, constraints.maxWidth);
                    finish();
                  },
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: dragging ? 8 : 3,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: ColoredBox(color: Colors.white24),
                              ),
                              FractionallySizedBox(
                                widthFactor: buffered,
                                heightFactor: 1,
                                child: const ColoredBox(color: Colors.white38),
                              ),
                              FractionallySizedBox(
                                widthFactor: progress,
                                heightFactor: 1,
                                child: const ColoredBox(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left:
                            (progress *
                            (constraints.maxWidth - (dragging ? 16 : 6))),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: dragging ? 16 : 6,
                          height: dragging ? 16 : 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
