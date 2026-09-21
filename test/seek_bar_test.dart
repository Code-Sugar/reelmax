import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:reelmax/src/seek_bar.dart';
import 'live_player_test.dart' show NetworkVideo;

void main() {
  testWidgets(
    'scrubbing seeks only the preview until release and preserves play/pause',
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
        expect(find.byKey(const ValueKey('seek-preview')), findsOneWidget);
        expect(platform.playing[0], false);
        await tester.pump(const Duration(milliseconds: 180));
        expect(platform.events, hasLength(2));
        expect(controller.value.position, const Duration(seconds: 5));
        expect(
          platform.positions[platform.nextId - 1]!.inMilliseconds,
          closeTo(22500, 150),
        );
        final previewId = platform.nextId - 1;
        expect(platform.sources[previewId]!.uri, platform.sources[0]!.uri);
        // Keep moving faster than the preview interval: updates must not wait
        // until the finger stops. The original debounce starved this case.
        for (var step = 0; step < 12; step++) {
          await gesture.moveTo(left + Offset(100 + step * 8, 18));
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(
          platform.positions[previewId]!.inMilliseconds,
          inInclusiveRange(10000, 18800),
        );
        expect(controller.value.position, const Duration(seconds: 5));
        await gesture.moveTo(left + const Offset(225, 18));
        for (var step = 0; step < 6; step++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(platform.positions[previewId]!.inMilliseconds, 22500);
        expect(platform.playing[previewId], false);
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
