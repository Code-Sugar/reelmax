import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:reelmax/src/account_state.dart';
import 'package:reelmax/src/api.dart';
import 'package:reelmax/src/data.dart';
import 'package:reelmax/src/live_player.dart';
import 'package:reelmax/src/player_panels.dart';
import 'package:reelmax/src/design.dart';
import 'package:reelmax/src/media.dart';
import 'package:reelmax/src/auth.dart';
import 'api_test.dart' show MemorySessionStorage, response;
import 'support/fake_video.dart';

class NetworkVideo extends FakeVideoPlatform {
  final speeds = <int, double>{};
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    speeds[playerId] = speed;
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);
}

void main() {
  test('extensionless signed backend URL explicitly selects HLS', () {
    expect(
      videoFormatHint(
        Uri.parse('http://server/skit-planet/skit/media/play?token=secret'),
      ),
      VideoFormat.hls,
    );
    expect(
      videoFormatHint(Uri.parse('https://cdn/movie.m3u8?sig=test')),
      VideoFormat.hls,
    );
    expect(videoFormatHint(Uri.parse('https://cdn/movie.mp4')), isNull);
  });

  testWidgets(
    'login-only episode prompts once, cancels cleanly and resumes after login',
    (tester) async {
      final platform = NetworkVideo();
      VideoPlayerPlatform.instance = platform;
      var plays = 0;
      final api = SkitApi(
        baseUrl: 'http://server/skit-planet/',
        storage: MemorySessionStorage(),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/dramaList')) {
            return response([
              {
                'id': 557,
                'isLogin': 1,
                'needPay': 0,
                'cover': 'battle-of-two-cities.png',
              },
            ]);
          }
          if (r.url.path.endsWith('/checkEmailExists')) {
            return response({'status': 1});
          }
          if (r.url.path.endsWith('/register')) {
            return response({
              'authorization': 'test-token',
              'info': {'id': 24, 'email': 'test@example.com'},
            });
          }
          if (r.url.path.endsWith('/skit/play')) {
            plays++;
            return response({
              'playUrl':
                  'http://server/skit-planet/skit/media/play?token=signed',
            });
          }
          if (r.url.path.endsWith('/media/play')) {
            return http.Response('#EXTM3U', 200);
          }
          return response({});
        }),
      );
      final account = AccountStore(api: api);
      await tester.pumpWidget(
        AccountScope(
          store: account,
          child: MaterialApp(
            home: LivePlayer(
              skit: const DramaInfo(
                serverId: 1,
                title: 'Test',
                image: 'battle-of-two-cities.png',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('episode-login-dialog')),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
      expect(plays, 0);
      await tester.tap(find.byKey(const ValueKey('episode-login-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('episode-login-dialog')), findsNothing);
      expect(find.text('Retry'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('episode-login-dialog')), findsNothing);
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('episode-login-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('episode-login-confirm')));
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);
      await account.loginEmail('test@example.com', 'test-password');
      tester
          .element(find.byType(AuthPage))
          .findAncestorStateOfType<NavigatorState>()!
          .pop();
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsNothing);
      expect(find.byKey(const ValueKey('episode-login-dialog')), findsNothing);
      expect(plays, 1);
      expect(platform.playing.values.where((v) => v), hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      account.dispose();
      api.dispose();
    },
  );

  testWidgets(
    'live playback uses HLS and original panels preserve position and server locks',
    (tester) async {
      final font = FontLoader('Commissioner')
        ..addFont(rootBundle.load('assets/fonts/Commissioner-Variable.ttf'));
      await font.load();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final platform = NetworkVideo();
      VideoPlayerPlatform.instance = platform;
      final played = <int>[];
      var reaction = Completer<http.Response>();
      const playUrl = 'http://server/skit-planet/skit/media/play?token=signed';
      final api = SkitApi(
        baseUrl: 'http://server/skit-planet/',
        storage: MemorySessionStorage(),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/likeDrama') ||
              r.url.path.endsWith('/collectDrama')) {
            return reaction.future;
          }
          if (r.url.path.endsWith('/dramaList')) {
            return response([
              for (var i = 1; i <= 6; i++)
                {
                  'id': i,
                  'cover': 'battle-of-two-cities.png',
                  'needPay': i == 3 ? 1 : 0,
                  'isUnlocked': 0,
                  'coin': 50,
                },
            ]);
          }
          if (r.url.path.endsWith('/skit/play')) {
            expect(r.headers['Authorization'], 'app-session-test');
            played.add(jsonDecode(r.body)['dramaId'] as int);
            return response({'playUrl': playUrl});
          }
          if (r.url.path.endsWith('/media/play')) {
            expect(r.headers.containsKey('Authorization'), isFalse);
            return http.Response(
              '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720\n?token=signed&playlist=720p.m3u8&playlistSig=test\n',
              200,
            );
          }
          return response({});
        }),
      );
      await api.setToken('app-session-test');
      final account = AccountStore(api: api);
      await tester.pumpWidget(
        AccountScope(
          store: account,
          child: MaterialApp(
            home: LivePlayer(
              skit: const DramaInfo(
                serverId: 1,
                title: 'Test',
                image: 'battle-of-two-cities.png',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.sources.values.first.formatHint, VideoFormat.hls);
      expect(platform.sources.values.first.uri, playUrl);
      expect(platform.sources.values.first.httpHeaders, isEmpty);
      expect(played, [1, 2]); // Next episode is ready before any swipe.
      expect(platform.playing[1], isNot(true));
      platform.positions[0] = const Duration(seconds: 8);
      await tester.pump(const Duration(milliseconds: 600));
      Finder control(String label) =>
          find.byWidgetPredicate((w) => w is CircleControl && w.label == label);
      LikeFeedback feedback(String label) => tester.widget<LikeFeedback>(
        find.ancestor(of: control(label), matching: find.byType(LikeFeedback)),
      );
      await tester.tap(control('Like'));
      await tester.pump();
      expect(reaction.isCompleted, isFalse);
      expect(feedback('Like').active, isTrue);
      reaction.complete(response({}));
      await tester.pumpAndSettle();
      expect(feedback('Like').active, isTrue);

      reaction = Completer<http.Response>();
      await tester.tap(control('Collect'));
      await tester.pump();
      expect(reaction.isCompleted, isFalse);
      expect(feedback('Saved').active, isTrue);
      reaction.complete(http.Response('{"code":500,"msg":"Failed"}', 200));
      await tester.pumpAndSettle();
      expect(feedback('Collect').active, isFalse);
      await tester.tap(control('Auto'));
      await tester.pumpAndSettle();
      expect(find.byType(QualityPanel), findsOneWidget);
      expect(find.byType(PlayerPanel), findsOneWidget);
      expect(platform.playing[0], false);
      final disabled = tester.widget<Pressable>(
        find.byKey(const ValueKey('quality-option-4K')),
      );
      expect(disabled.onTap, isNull);
      await tester.tap(find.byKey(const ValueKey('quality-option-720p')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(platform.sources[2]!.formatHint, VideoFormat.hls);
      expect(platform.sources[2]!.uri, contains('playlistSig=test'));
      expect(platform.sources[2]!.httpHeaders, isEmpty);
      expect(platform.positions[2], const Duration(seconds: 8));
      expect(platform.playing[2], true);
      await tester.tap(control('List'));
      await tester.pumpAndSettle();
      expect(find.byType(EpisodePanel), findsOneWidget);
      expect(find.byType(PlayerPanel), findsOneWidget);
      expect(find.byKey(const ValueKey('episode-lock-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('episode-lock-4')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('episode-option-2')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(played, [1, 2]);
      expect(find.text('Episodes 02'), findsOneWidget);
      Future<void> selectEpisode(int number) async {
        await tester.tap(control('List'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('episode-option-$number')));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
      }

      platform.positions[1] = const Duration(seconds: 12);
      await tester.pump(const Duration(milliseconds: 600));
      await selectEpisode(1);
      // Reuse the same decoder, buffered data, resolution and last position.
      expect(played, [1, 2]);
      expect(platform.sources, hasLength(3));
      expect(platform.positions[2], const Duration(seconds: 8));
      expect(
        find.byWidgetPredicate((w) => w is CircleControl && w.label == '720p'),
        findsOneWidget,
      );
      expect(platform.playing[2], true);
      expect(platform.playing[1], false);
      await selectEpisode(2);
      expect(platform.positions[1], const Duration(seconds: 12));
      expect(played, [1, 2]);
      await selectEpisode(4);
      await selectEpisode(5);
      expect(platform.events.length, 3);
      expect(platform.events.containsKey(2), false);
      await selectEpisode(2);
      // The evicted previous episode is prepared again before navigating back.
      expect(played, [1, 2, 4, 5, 6, 2, 1]);
      await selectEpisode(1);
      expect(played, [1, 2, 4, 5, 6, 2, 1]);
      expect(
        platform.positions[platform.playing.entries
            .singleWhere((e) => e.value)
            .key],
        const Duration(seconds: 8),
      );
      expect(platform.events.length, 3);
      expect(platform.playing.values.where((v) => v), hasLength(1));
      final gestureArea = find.byKey(const ValueKey('live-video-gesture-0'));
      final center = tester.getCenter(gestureArea);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));
      AnimatedOpacity chromeState() => tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: control('List'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(chromeState().opacity, 0);
      // The first tap reveals controls without interrupting playback.
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(chromeState().opacity, 1);
      expect(platform.playing.values.where((v) => v), hasLength(1));
      // With controls visible, a second tap pauses.
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(platform.playing.values.where((v) => v), isEmpty);
      await tester.pump(const Duration(seconds: 3));
      expect(chromeState().opacity, 1);
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(chromeState().opacity, 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(chromeState().opacity, 0);
      final activeId = platform.playing.entries.singleWhere((e) => e.value).key;
      for (var cycle = 0; cycle < 2; cycle++) {
        platform.events[activeId]!.add(
          VideoEvent(eventType: VideoEventType.bufferingStart),
        );
        platform.events[activeId]!.add(
          VideoEvent(
            eventType: VideoEventType.isPlayingStateUpdate,
            isPlaying: false,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(chromeState().opacity, 0);
        platform.events[activeId]!.add(
          VideoEvent(eventType: VideoEventType.bufferingEnd),
        );
        platform.events[activeId]!.add(
          VideoEvent(
            eventType: VideoEventType.isPlayingStateUpdate,
            isPlaying: true,
          ),
        );
        await tester.pump(const Duration(seconds: 3));
        expect(chromeState().opacity, 0);
      }
      for (final x in [20.0, 370.0]) {
        final hold = await tester.startGesture(Offset(x, 340));
        await tester.pump(const Duration(milliseconds: 650));
        expect(platform.speeds[activeId], 2);
        expect(
          tester
              .widget<AnimatedOpacity>(
                find.byKey(const ValueKey('double-speed-indicator')),
              )
              .opacity,
          1,
        );
        await hold.up();
        await tester.pump(const Duration(milliseconds: 250));
        expect(platform.speeds[activeId], 1);
        expect(
          tester
              .widget<AnimatedOpacity>(
                find.byKey(const ValueKey('double-speed-indicator')),
              )
              .opacity,
          0,
        );
      }
      final requestsBeforeCompletion = played.length;
      final outgoing = tester
          .widget<VideoCover>(find.byType(VideoCover).first)
          .controller;
      platform.complete(activeId);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      // Both textures stay mounted while the page transition crosses its midpoint.
      expect(
        find.byWidgetPredicate(
          (w) => w is VideoCover && identical(w.controller, outgoing),
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Episodes 02'), findsOneWidget);
      expect(played.length, requestsBeforeCompletion);
      expect(platform.playing.values.where((v) => v), hasLength(1));
      // Returning once to a completed episode restarts it, without bouncing ahead.
      await tester.drag(find.byType(PageView), const Offset(0, 650));
      await tester.pumpAndSettle();
      expect(find.text('Episodes 01'), findsOneWidget);
      expect(platform.positions[activeId], Duration.zero);
      expect(platform.playing[activeId], true);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Episodes 01'), findsOneWidget);
      expect(played.length, requestsBeforeCompletion);
      tester.binding.handleMemoryPressure();
      final dynamic playerState = tester.state(find.byType(LivePlayer));
      expect(playerState.memoryConstrained, isTrue);
      expect(playerState.cachedEpisodes.length, 1);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(platform.events, hasLength(1));
      expect(platform.playing.values.where((v) => v), hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      account.dispose();
      api.dispose();
    },
  );
}
