import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelmax/src/data.dart';
import 'package:reelmax/src/home.dart';
import 'package:reelmax/src/home_video_pool.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Initialization is controlled independently of widget frames, as on a device.
class _ControlledVideoPlatform extends VideoPlayerPlatform {
  _ControlledVideoPlatform({
    this.automatic = true,
    this.failFirstCreate = false,
  });

  final bool automatic, failFirstCreate;
  final sources = <int, DataSource>{};
  final events = <int, StreamController<VideoEvent>>{};
  final playing = <int, bool>{};
  final positions = <int, Duration>{};
  final attempts = <String>[];
  int _nextId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final source = options.dataSource;
    attempts.add(source.uri ?? source.asset!);
    if (failFirstCreate && attempts.length == 1) {
      throw PlatformException(code: 'temporary-native-create-failure');
    }
    final id = _nextId++;
    sources[id] = source;
    events[id] = StreamController<VideoEvent>();
    positions[id] = Duration.zero;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    if (automatic) scheduleMicrotask(() => initialize(playerId));
    return events[playerId]!.stream;
  }

  void initialize(int id) => events[id]?.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 30),
      size: const Size(1080, 1920),
    ),
  );

  @override
  Future<void> dispose(int playerId) async {
    unawaited(events.remove(playerId)?.close());
    playing[playerId] = false;
  }

  @override
  Future<void> play(int playerId) async {
    playing[playerId] = true;
  }

  @override
  Future<void> pause(int playerId) async {
    playing[playerId] = false;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => positions[playerId]!;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);
}

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
}

void main() {
  const first = 'https://example.test/first.mp4';
  const second = 'https://example.test/second.mp4';

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('native create failure neither blocks Next nor needs navigation '
      'to recover the current video', (tester) async {
    final platform = _ControlledVideoPlatform(failFirstCreate: true);
    VideoPlayerPlatform.instance = platform;
    final pool = HomeVideoPool();
    pool.configure([first, second], {first, second});
    await _flush(tester);
    await tester.pump(const Duration(seconds: 2));
    await _flush(tester);

    final next = pool.controllerFor(second);
    expect(
      next,
      isNotNull,
      reason:
          'Failed native creation must not stall '
          'the serial pool in VideoPlayerController.dispose().',
    );
    expect(next!.value.isPlaying, isTrue);

    // Do not call configure again: retry must also work on an untouched screen.
    for (var i = 0; i < 8 && pool.controllerFor(first) == null; i++) {
      await tester.pump(const Duration(seconds: 1));
      await _flush(tester);
    }
    expect(pool.controllerFor(first), isNotNull);
    expect(pool.controllerFor(first)!.value.isPlaying, isTrue);
    expect(platform.attempts.where((source) => source == first).length, 2);
    expect(identical(next, pool.controllerFor(second)), isTrue);
    pool.dispose();
    await _flush(tester);
    expect(platform.events, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delayed initialization starts playback when the native event '
      'arrives without another configure call', (tester) async {
    final platform = _ControlledVideoPlatform(automatic: false);
    VideoPlayerPlatform.instance = platform;
    final pool = HomeVideoPool();
    pool.configure([first], {first});
    await _flush(tester);
    expect(platform.events.length, 1);
    expect(pool.controllerFor(first), isNull);
    await tester.pump(const Duration(seconds: 3));
    expect(pool.controllerFor(first), isNull);

    platform.initialize(platform.events.keys.single);
    await _flush(tester);
    expect(pool.controllerFor(first), isNotNull);
    expect(pool.controllerFor(first)!.value.isPlaying, isTrue);
    expect(platform.attempts, [first]);
    pool.dispose();
    await _flush(tester);
    expect(platform.events, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'visible initial inactive home plays without waiting for a resume event',
    (tester) async {
      final platform = _ControlledVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final pool = HomeVideoPool();
      pool.configure([first], {first});
      await _flush(tester);
      expect(pool.controllerFor(first), isNotNull);
      expect(pool.controllerFor(first)!.value.isPlaying, isTrue);
      // This is the exact retained state produced by the old constructor.
      pool.foreground = false;
      pool.configure([first], {first});
      await _flush(tester);
      expect(pool.foreground, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await _flush(tester);
      expect(pool.controllerFor(first)!.value.isPlaying, isFalse);
      pool.configure([first], {first});
      await _flush(tester);
      expect(pool.controllerFor(first)!.value.isPlaying, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _flush(tester);
      expect(pool.controllerFor(first), isNotNull);
      expect(pool.controllerFor(first)!.value.isPlaying, isTrue);
      expect(platform.attempts, [first]);
      pool.dispose();
      await _flush(tester);
      expect(platform.events, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home created in background waits for resume', (tester) async {
    final platform = _ControlledVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final pool = HomeVideoPool();
    pool.configure([first], {first});
    await _flush(tester);
    expect(platform.attempts, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _flush(tester);
    expect(pool.controllerFor(first)!.value.isPlaying, isTrue);
    pool.dispose();
    await _flush(tester);
  });

  testWidgets('home replaces the poster with an actual VideoPlayer after '
      'asynchronous native initialization', (tester) async {
    final platform = _ControlledVideoPlatform(automatic: false);
    VideoPlayerPlatform.instance = platform;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(
            active: true,
            openDetail: (_) {},
            openSearch: () {},
            items: const [
              Feature(
                'Test drama',
                'Drama',
                '',
                '',
                'battle-of-two-cities.png',
                first,
              ),
            ],
          ),
        ),
      ),
    );
    await _flush(tester);
    final heroPlayer = find.descendant(
      of: find.byKey(const ValueKey('home-video-0')),
      matching: find.byType(VideoPlayer),
    );
    expect(heroPlayer, findsNothing);
    expect(platform.events.length, 1);
    // Several frames with identical constraints should not affect readiness.
    await tester.pump(const Duration(milliseconds: 350));
    platform.initialize(platform.events.keys.single);
    await _flush(tester);

    expect(
      heroPlayer,
      findsOneWidget,
      reason:
          'Successful initialization must rebuild the LayoutBuilder '
          'content, not only mark the parent HomePage dirty.',
    );
    expect(
      tester.widget<VideoPlayer>(heroPlayer).controller.value.isPlaying,
      isTrue,
    );
    expect(platform.attempts, [first]);
    await tester.pumpWidget(const SizedBox());
    await _flush(tester);
    expect(platform.events, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
