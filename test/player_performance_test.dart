import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:reelmax/src/account_state.dart';
import 'package:reelmax/src/api.dart';
import 'package:reelmax/src/data.dart';
import 'package:reelmax/src/design.dart';
import 'package:reelmax/src/live_player.dart';
import 'api_test.dart' show MemorySessionStorage, response;
import 'live_player_test.dart' show NetworkVideo;

void main() {
  Future<void> mount(WidgetTester tester, AccountStore account) async {
    await tester.pumpWidget(
      AccountScope(
        store: account,
        child: const MaterialApp(
          home: LivePlayer(
            skit: DramaInfo(
              serverId: 1,
              title: 'Test',
              image: 'battle-of-two-cities.png',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> cleanUp(
    WidgetTester tester,
    AccountStore account,
    SkitApi api,
  ) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    account.dispose();
    api.dispose();
  }

  for (final extension in ['mp4', 'm3u8']) {
    testWidgets(
      '$extension quality lookup never downloads MP4 or repeats cached HLS',
      (tester) async {
        final platform = NetworkVideo();
        VideoPlayerPlatform.instance = platform;
        final mediaReads = <String>[];
        final api = SkitApi(
          baseUrl: 'http://server/skit-planet/',
          storage: MemorySessionStorage(),
          client: MockClient((request) async {
            if (request.url.path.endsWith('/dramaList')) {
              return response([
                for (var id = 1; id <= 2; id++)
                  {'id': id, 'cover': 'battle-of-two-cities.png'},
              ]);
            }
            if (request.url.path.endsWith('/skit/play')) {
              final id = jsonDecode(request.body)['dramaId'];
              return response({'playUrl': 'https://cdn/$id.$extension'});
            }
            if (request.url.host == 'cdn') {
              mediaReads.add(request.url.path);
              return http.Response('#EXTM3U\n#EXT-X-TARGETDURATION:4', 200);
            }
            return response({});
          }),
        );
        final account = AccountStore(api: api);
        await mount(tester, account);
        await tester.drag(find.byType(PageView), const Offset(0, -650));
        await tester.pumpAndSettle();
        expect(find.text('Episodes 02'), findsOneWidget);
        await tester.drag(find.byType(PageView), const Offset(0, 650));
        await tester.pumpAndSettle();
        expect(find.text('Episodes 01'), findsOneWidget);
        expect(
          mediaReads,
          extension == 'mp4' ? isEmpty : ['/1.m3u8', '/2.m3u8'],
        );
        expect(platform.sources, hasLength(2));
        expect(
          platform.playing.values.where((playing) => playing),
          hasLength(1),
        );
        await cleanUp(tester, account, api);
      },
    );
  }

  testWidgets('background releases neighbours and resumes the current decoder', (
    tester,
  ) async {
    final platform = NetworkVideo();
    VideoPlayerPlatform.instance = platform;
    final played = <int>[];
    final api = SkitApi(
      baseUrl: 'http://server/skit-planet/',
      storage: MemorySessionStorage(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/dramaList')) {
          return response([
            for (var id = 1; id <= 3; id++)
              {'id': id, 'cover': 'battle-of-two-cities.png'},
          ]);
        }
        if (request.url.path.endsWith('/skit/play')) {
          final id = jsonDecode(request.body)['dramaId'] as int;
          played.add(id);
          return response({'playUrl': 'https://cdn/$id.mp4'});
        }
        return response({});
      }),
    );
    final account = AccountStore(api: api);
    await mount(tester, account);
    platform.positions[0] = const Duration(seconds: 9);
    await tester.pump(const Duration(milliseconds: 600));
    expect(platform.events, hasLength(2));
    // A transient interruption, such as the notification shade, retains cache.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(platform.events, hasLength(2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    final dynamic player = tester.state(find.byType(LivePlayer));
    expect(player.cachedEpisodes.length, 1);
    // VideoPlayerController waits for subscription cancellation before calling
    // the fake platform's dispose. Flush that real async completion as well as
    // widget frames (the seek-bar disposal test uses the same lifecycle).
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(platform.events.keys, [0]);
    expect(platform.playing.values.where((playing) => playing), isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(platform.events, hasLength(2));
    expect(platform.playing[0], isTrue);
    expect(platform.positions[0], const Duration(seconds: 9));
    expect(played, [1, 2, 2]);
    await cleanUp(tester, account, api);
  });

  testWidgets(
    'a pre-background preload cannot allocate a decoder after resume',
    (tester) async {
      final platform = NetworkVideo();
      VideoPlayerPlatform.instance = platform;
      final pending = Completer<http.Response>();
      var neighbourRequests = 0;
      final api = SkitApi(
        baseUrl: 'http://server/skit-planet/',
        storage: MemorySessionStorage(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/dramaList')) {
            return response([
              for (var id = 1; id <= 2; id++)
                {'id': id, 'cover': 'battle-of-two-cities.png'},
            ]);
          }
          if (request.url.path.endsWith('/skit/play')) {
            final id = jsonDecode(request.body)['dramaId'] as int;
            if (id == 2 && ++neighbourRequests == 1) return pending.future;
            return response({'playUrl': 'https://cdn/$id.mp4'});
          }
          return response({});
        }),
      );
      final account = AccountStore(api: api);
      await mount(tester, account);
      expect(platform.sources, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      pending.complete(response({'playUrl': 'https://cdn/stale.mp4'}));
      await tester.pumpAndSettle();
      expect(neighbourRequests, 2);
      expect(platform.sources.values.map((source) => source.uri), [
        'https://cdn/1.mp4',
        'https://cdn/2.mp4',
      ]);
      await cleanUp(tester, account, api);
    },
  );

  testWidgets('failed quality lookup retries and updates an already open panel', (
    tester,
  ) async {
    final platform = NetworkVideo();
    VideoPlayerPlatform.instance = platform;
    final retry = Completer<http.Response>();
    var lookups = 0;
    final api = SkitApi(
      baseUrl: 'http://server/skit-planet/',
      storage: MemorySessionStorage(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/dramaList')) {
          return response([
            {'id': 1, 'cover': 'battle-of-two-cities.png'},
          ]);
        }
        if (request.url.path.endsWith('/skit/play')) {
          return response({'playUrl': 'https://cdn/master.m3u8'});
        }
        if (request.url.host == 'cdn') {
          if (++lookups == 1) return http.Response('Unavailable', 503);
          return retry.future;
        }
        return response({});
      }),
    );
    final account = AccountStore(api: api);
    await mount(tester, account);
    // Complete cancellation of the failed streamed response before retrying.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.tap(
      find.byWidgetPredicate((w) => w is CircleControl && w.label == 'Auto'),
    );
    await tester.pumpAndSettle();
    expect(lookups, 2);
    final option = find.byKey(const ValueKey('quality-option-720p'));
    expect(tester.widget<Pressable>(option).onTap, isNull);
    retry.complete(
      http.Response(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720\n720p.m3u8\n',
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Pressable>(option).onTap, isNotNull);
    await tester.tap(option);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(platform.sources[1]?.uri, 'https://cdn/720p.m3u8');
    expect(lookups, 2);
    await cleanUp(tester, account, api);
  });
}
