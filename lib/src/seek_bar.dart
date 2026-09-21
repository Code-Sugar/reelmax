import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'design.dart';
import 'media.dart';

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
  String time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
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
              if (dragging)
                Positioned(
                  bottom: 52,
                  left: (progress * constraints.maxWidth - 47).clamp(
                    0.0,
                    (constraints.maxWidth - 94).clamp(0.0, double.infinity),
                  ),
                  child: IgnorePointer(
                    child: Container(
                      key: const ValueKey('seek-preview'),
                      width: 94,
                      height: 144,
                      decoration: BoxDecoration(
                        color: const Color(0xff161b18),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: Colors.white54),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 18),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          children: [
                            Expanded(
                              child: _SeekPreview(
                                key: ObjectKey(widget.controller),
                                source: widget.controller,
                                position: target,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Text(
                                time(target),
                                style: type(12, weight: 650),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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

/// A single, muted decoder owned only by the active drag. Never seeks the
/// playback controller; rapid pointer updates coalesce to the latest target.
class _SeekPreview extends StatefulWidget {
  const _SeekPreview({super.key, required this.source, required this.position});
  final VideoPlayerController source;
  final Duration position;
  @override
  State<_SeekPreview> createState() => _SeekPreviewState();
}

class _SeekPreviewState extends State<_SeekPreview> {
  VideoPlayerController? preview;
  Timer? timer;
  bool ready = false, busy = false, failed = false;
  Duration? rendered;

  @override
  void initState() {
    super.initState();
    // A simple tap commits immediately without allocating a preview decoder.
    timer = Timer(const Duration(milliseconds: 120), initialize);
  }

  Future<void> initialize() async {
    final source = widget.source;
    final controller = source.dataSourceType == DataSourceType.asset
        ? VideoPlayerController.asset(
            source.dataSource,
            package: source.package,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
        : VideoPlayerController.networkUrl(
            Uri.parse(source.dataSource),
            formatHint: source.formatHint,
            httpHeaders: source.httpHeaders,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
    preview = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setVolume(0);
      if (!mounted) return;
      setState(() => ready = true);
      // Attach the texture before decoding the requested frame.
      await WidgetsBinding.instance.endOfFrame;
      await seekLatest();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant _SeekPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position && ready) {
      // Throttle, not debounce: uninterrupted dragging must keep updating.
      if (!busy && !(timer?.isActive ?? false)) {
        timer = Timer(const Duration(milliseconds: 100), seekLatest);
      }
    }
  }

  Future<void> seekLatest() async {
    if (!ready || busy || !mounted) return;
    busy = true;
    try {
      while (mounted && rendered != widget.position) {
        final position = widget.position;
        rendered = null;
        final controller = preview!;
        // seekTo acknowledges the command, not delivery of a new texture.
        // Brief muted playback lets paused HLS decoders produce fresh frames.
        await controller.seekTo(position);
        if (!mounted) return;
        await controller.play();
        var available = false;
        for (var attempt = 0; attempt < 25 && mounted; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          if (!mounted) return;
          if (position != widget.position) break;
          final actual = await controller.position;
          if (!mounted) return;
          if (controller.value.hasError) {
            throw StateError('Preview decode failed');
          }
          if (!controller.value.isBuffering &&
              actual != null &&
              actual >= position &&
              (actual - position).inMilliseconds < 1000) {
            available = true;
            break;
          }
        }
        if (!mounted) return;
        await controller.pause();
        if (!mounted) return;
        if (position != widget.position) continue;
        if (!available) throw StateError('Preview frame timed out');
        setState(() {
          failed = false;
          rendered = position;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      busy = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    unawaited(preview?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (ready) VideoCover(controller: preview!),
      // Never label an old frame with the newly requested timestamp.
      if (rendered != widget.position || failed)
        const ColoredBox(color: Color(0xff161b18)),
      if (failed)
        const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.white54,
            size: 22,
          ),
        )
      else if (rendered != widget.position)
        const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.white,
            ),
          ),
        ),
    ],
  );
}
