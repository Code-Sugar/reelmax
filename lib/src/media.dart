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

/// A view of a shared decoder; ownership belongs to the home video pool.
class PreviewVideo extends StatelessWidget {
  const PreviewVideo({
    super.key,
    required this.source,
    required this.poster,
    required this.controller,
  });
  final String source, poster;
  final VideoPlayerController? controller;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Stack(
      fit: StackFit.expand,
      children: [
        // This same poster expands from the Next card to full screen. Keep a
        // stable image cache key throughout that size animation.
        Art(poster, decodeToDisplaySize: false),
        if (controller != null) VideoCover(controller: controller!),
      ],
    ),
  );
}

class VideoCover extends StatelessWidget {
  const VideoCover({super.key, required this.controller});
  final VideoPlayerController controller;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    ),
  );
}
