import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'design.dart';

// The backend's signed HLS endpoint has no .m3u8 suffix, so Android cannot
// infer the media source type from its URI. Keep the signed URI unchanged.
VideoFormat? videoFormatHint(Uri uri) =>
    uri.path.toLowerCase().endsWith('.m3u8') ||
        uri.path.endsWith('/skit/media/play')
    ? VideoFormat.hls
    : null;

/// Bundled original media; no server or credentials are needed for playback.
class PreviewVideo extends StatefulWidget {
  const PreviewVideo({
    super.key,
    required this.source,
    required this.poster,
    this.active = true,
  });
  final String source, poster;
  final bool active;
  @override
  State<PreviewVideo> createState() => _PreviewVideoState();
}

class _PreviewVideoState extends State<PreviewVideo>
    with WidgetsBindingObserver {
  late final VideoPlayerController controller;
  bool ready = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = widget.source.startsWith('http')
        ? VideoPlayerController.networkUrl(
            Uri.parse(widget.source),
            formatHint: videoFormatHint(Uri.parse(widget.source)),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
        : VideoPlayerController.asset(
            'assets/${widget.source}',
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
    if (widget.source.isNotEmpty) initialize();
  }

  Future<void> initialize() async {
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setVolume(0);
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() => ready = true);
      if (widget.active) await controller.play();
    } catch (error) {
      debugPrint('Preview ${widget.source}: $error');
    }
  }

  @override
  void didUpdateWidget(covariant PreviewVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (ready && oldWidget.active != widget.active) {
      widget.active ? controller.play() : controller.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ready) return;
    if (state == AppLifecycleState.resumed && widget.active) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Art(widget.poster),
      if (ready) VideoCover(controller: controller),
    ],
  );
}

class VideoCover extends StatelessWidget {
  const VideoCover({super.key, required this.controller});
  final VideoPlayerController controller;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    ),
  );
}
