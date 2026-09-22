import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:reelmax/src/home_video_pool.dart';
import 'live_player_test.dart' show NetworkVideo;

void main() {
  testWidgets('home keeps three decoders, reuses Next and releases off-page', (
    tester,
  ) async {
    final platform = NetworkVideo();
    VideoPlayerPlatform.instance = platform;
    final pool = HomeVideoPool();
    final urls = List.generate(20, (i) => 'https://example.test/$i.mp4');
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
    }

    pool.configure([urls[0], urls[1], urls[19]], {urls[0], urls[1]});
    await settle();
    expect(platform.events.length, 3);
    expect(platform.sources.length, 3);
    final next = pool.controllerFor(urls[1]);
    expect(next, isNotNull);
    // The teaser and expanded hero query the same native decoder.
    expect(identical(next, pool.controllerFor(urls[1])), isTrue);
    pool.configure([urls[1], urls[2], urls[0]], {urls[1], urls[2]});
    await settle();
    expect(identical(next, pool.controllerFor(urls[1])), isTrue);
    expect(platform.events.length, 3);
    for (var i = 2; i < 12; i++) {
      pool.configure([urls[i], urls[i + 1], urls[i - 1]], {urls[i]});
      await settle();
      expect(platform.events.length, 3);
      expect(platform.playing.values.where((v) => v).length, 1);
    }
    final current = pool.controllerFor(urls[11])!;
    await current.seekTo(const Duration(seconds: 7));
    pool.configure([], {});
    await settle();
    expect(platform.events, isEmpty);
    pool.configure([urls[11], urls[12], urls[10]], {urls[11]});
    await settle();
    expect(
      pool.controllerFor(urls[11])!.value.position,
      const Duration(seconds: 7),
    );
    pool.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await settle();
    expect(platform.events.length, 3);
    expect(platform.playing.values.where((value) => value), isEmpty);
    pool.didChangeAppLifecycleState(AppLifecycleState.paused);
    await settle();
    expect(platform.events, isEmpty);
    pool.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();
    expect(platform.events.length, 3);
    pool.dispose();
    await settle();
    expect(platform.events, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
