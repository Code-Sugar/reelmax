import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:reelmax/src/seek_bar.dart';
import 'live_player_test.dart' show NetworkVideo;

void main() {
  testWidgets(
    'scrubbing uses no preview decoder and seeks on release preserving play/pause',
    (tester) async {
      final platform = NetworkVideo();
      VideoPlayerPlatform.instance = platform;
      final controller = VideoPlayerController.networkUrl(
        Uri.parse('https://example.test/video.mp4'),
      );
      await controller.initialize();
      await controller.play();
      final changes = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: EpisodeSeekBar(
                  controller: controller,
                  onScrubbing: changes.add,
                ),
              ),
            ),
          ),
        ),
      );
      for (final wasPlaying in [true, false]) {
        wasPlaying ? await controller.play() : await controller.pause();
        await controller.seekTo(const Duration(seconds: 5));
        final bar = find.byKey(const ValueKey('episode-seek-bar'));
        final left = tester.getTopLeft(bar);
        final gesture = await tester.startGesture(left + const Offset(50, 18));
        await gesture.moveTo(left + const Offset(100, 18));
        await tester.pump();
        await gesture.moveTo(left + const Offset(225, 18));
        await tester.pump(const Duration(milliseconds: 180));
        expect(find.byKey(const ValueKey('seek-preview')), findsNothing);
        expect(platform.playing[0], false);
        expect(controller.value.position, const Duration(seconds: 5));
        // Sustained dragging must not allocate a decoder or move playback.
        for (var step = 0; step < 12; step++) {
          await gesture.moveTo(left + Offset(100 + step * 8, 18));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await gesture.moveTo(left + const Offset(225, 18));
        await tester.pump(const Duration(milliseconds: 600));
        expect(platform.sources, hasLength(1));
        expect(platform.events, hasLength(1));
        expect(controller.value.position, const Duration(seconds: 5));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('seek-preview')), findsNothing);
        expect(platform.playing[0], wasPlaying);
        expect(controller.value.position.inMilliseconds, closeTo(22500, 150));
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        expect(platform.events, hasLength(1));
        expect(changes.last, false);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.pumpAndSettle();
    },
  );
}
