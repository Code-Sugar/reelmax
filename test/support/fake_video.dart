import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Exercises the real controller lifecycle while replacing platform textures.
class FakeVideoPlatform extends VideoPlayerPlatform {
  final Map<String, Uint8List> frames = {
    for (final file in Directory(
      'reference/frames',
    ).listSync().whereType<File>())
      file.uri.pathSegments.last: file.readAsBytesSync(),
  };
  final sources = <int, DataSource>{};
  final events = <int, StreamController<VideoEvent>>{};
  final positions = <int, Duration>{};
  final playing = <int, bool>{};
  int nextId = 0;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = nextId++;
    sources[id] = options.dataSource;
    events[id] = StreamController<VideoEvent>();
    positions[id] = Duration.zero;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    scheduleMicrotask(
      () => events[playerId]?.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 30),
          size: const Size(1080, 1920),
        ),
      ),
    );
    return events[playerId]!.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    await events.remove(playerId)?.close();
    playing[playerId] = false;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async {
    playing[playerId] = true;
  }

  @override
  Future<void> pause(int playerId) async {
    playing[playerId] = false;
  }

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
  Future<Duration> getPosition(int playerId) async =>
      positions[playerId] ?? Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    final source = sources[options.playerId]!.asset!
        .split('/')
        .last
        .replaceAll('.mp4', '.png');
    return Image.memory(frames[source]!, fit: BoxFit.cover);
  }

  void complete(int id) =>
      events[id]!.add(VideoEvent(eventType: VideoEventType.completed));
}
