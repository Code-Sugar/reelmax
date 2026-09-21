import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:reelmax/src/account_state.dart';
import 'package:reelmax/src/api.dart';
import 'package:reelmax/src/category.dart';
import 'package:reelmax/src/data.dart';
import 'package:reelmax/src/detail.dart';
import 'package:reelmax/src/live_catalog.dart';
import 'package:reelmax/src/live_player.dart';
import 'package:reelmax/src/home.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'live_player_test.dart' show NetworkVideo;
import 'api_test.dart' show MemorySessionStorage, response;

void main() {
  setUp(() async {
    final font = FontLoader('Commissioner')
      ..addFont(rootBundle.load('assets/fonts/Commissioner-Variable.ttf'));
    await font.load();
  });
  testWidgets(
    'home uses the single Max tab returned by show and renders videos',
    (tester) async {
      VideoPlayerPlatform.instance = NetworkVideo();
      final api = SkitApi(
        storage: MemorySessionStorage(),
        client: MockClient((r) async {
          expect(r.url.path, endsWith('/skit/show'));
          return response({
            'tabs': [
              {
                'id': 4,
                'tabName': 'Max',
                'sort': 1,
                'status': 1,
                'dramas': [
                  {
                    'id': 8,
                    'dramaId': 557,
                    'skitId': 1,
                    'skitName': 'A Killer Hiding in Plain Sight',
                    'cover': 'battle-of-two-cities.png',
                    'dramaSerie': 'https://video.example/master.m3u8',
                    'skitGenres': [],
                  },
                ],
              },
            ],
          });
        }),
      );
      final account = AccountStore(api: api);
      await tester.pumpWidget(
        AccountScope(
          store: account,
          child: MaterialApp(
            home: Scaffold(
              body: LiveHome(
                active: false,
                openDetail: (_) {},
                openSearch: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Max'), findsOneWidget);
      for (final label in [
        'New',
        'Top',
        'Exclusive',
        'No videos available yet.',
      ]) {
        expect(find.text(label), findsNothing);
      }
      final home = tester.widget<HomePage>(find.byType(HomePage));
      expect(home.selectedFilter, 'Max');
      expect(home.items!.single.serverId, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      account.dispose();
      api.dispose();
    },
  );

  testWidgets(
    'live catalog displays server titles and modules in the original shell',
    (tester) async {
      final api = SkitApi(
        storage: MemorySessionStorage(),
        client: MockClient(
          (r) async => response({
            'init': [
              {
                'title': 'test',
                'module': [
                  {
                    'title': 'unknown section',
                    'skits': [
                      {'id': 7, 'name': 'unmapped'},
                    ],
                  },
                ],
              },
            ],
          }),
        ),
      );
      final account = AccountStore(api: api);
      await tester.pumpWidget(
        AccountScope(
          store: account,
          child: MaterialApp(
            home: Scaffold(body: LiveCategory(openDetail: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CategoryPage), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Explore Genres'), findsOneWidget);
      expect(find.text('test'), findsOneWidget);
      expect(find.text('unknown section'), findsOneWidget);
      expect(find.text('unmapped'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      account.dispose();
      api.dispose();
    },
  );

  testWidgets('genre selection refreshes modules and ignores stale responses', (
    tester,
  ) async {
    final requests = <Completer<http.Response>>[];
    Map<String, dynamic> payload(String suffix) => {
      'init': [
        {
          'id': 1,
          'title': 'Fresh',
          'module': [
            {
              'id': 11,
              'title': 'First $suffix',
              'style': 3,
              'skits': [
                {
                  'id': 1,
                  'name': 'Drama A',
                  'cover': 'battle-of-two-cities.png',
                },
              ],
            },
          ],
        },
        {
          'id': 2,
          'title': 'Trending',
          'module': [
            {
              'id': 12,
              'title': 'Second $suffix',
              'style': 4,
              'skits': [
                {
                  'id': 2,
                  'name': 'Drama B',
                  'cover': 'battle-of-two-cities.png',
                },
              ],
            },
          ],
        },
      ],
    };
    final api = SkitApi(
      storage: MemorySessionStorage(),
      client: MockClient((r) {
        expect(r.url.path, endsWith('/skit/init'));
        final pending = Completer<http.Response>();
        requests.add(pending);
        return pending.future;
      }),
    );
    final account = AccountStore(api: api);
    await tester.pumpWidget(
      AccountScope(
        store: account,
        child: MaterialApp(
          home: Scaffold(body: LiveCategory(openDetail: (_) {})),
        ),
      ),
    );
    requests[0].complete(response(payload('initial')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trending'));
    await tester.pump();
    await tester.tap(find.text('Fresh'));
    await tester.pump();
    expect(requests.length, 3);
    requests[2].complete(response(payload('latest')));
    await tester.pumpAndSettle();
    requests[1].complete(response(payload('stale')));
    await tester.pumpAndSettle();
    expect(find.text('First latest'), findsOneWidget);
    expect(find.text('First stale'), findsNothing);
    expect(find.text('Second latest'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    account.dispose();
    api.dispose();
  });

  testWidgets('history opens the exact episode ID and saved position', (
    tester,
  ) async {
    final platform = NetworkVideo();
    VideoPlayerPlatform.instance = platform;
    final played = <int>[];
    final api = SkitApi(
      storage: MemorySessionStorage(),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/init')) return response({'init': []});
        if (r.url.path.endsWith('/dramaList')) {
          return response([
            {'id': 10, 'episodeTitle': 'First'},
            {'id': 30, 'episodeTitle': 'Second'},
          ]);
        }
        if (r.url.path.endsWith('/play')) {
          played.add((jsonDecode(r.body) as Map)['dramaId'] as int);
          return response({'playUrl': 'https://video.example/episode.m3u8'});
        }
        if (r.url.path.endsWith('.m3u8')) return http.Response('#EXTM3U', 200);
        return response({});
      }),
    );
    final account = AccountStore(api: api);
    await account.watchHistory.record('guest', {
      'skitId': 7,
      'dramaId': 30,
      'skitName': 'Watched show',
      'episodeTitle': 'Second',
      'cover': 'battle-of-two-cities.png',
      'positionMs': 12000,
      'durationMs': 30000,
    });
    await tester.pumpWidget(
      AccountScope(
        store: account,
        child: MaterialApp(
          home: Scaffold(body: LiveCategory(openDetail: (_) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Watched show'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('0:12 / 0:30'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-7-30')));
    await tester.pumpAndSettle();
    expect(find.byType(LivePlayer), findsOneWidget);
    expect(find.text('Episodes 02'), findsOneWidget);
    expect(played.first, 30);
    expect(platform.positions[0], const Duration(seconds: 12));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    account.dispose();
    api.dispose();
  });

  testWidgets(
    'live detail fills original design and retains fixed missing content',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var requests = 0;
      final api = SkitApi(
        storage: MemorySessionStorage(),
        client: MockClient((r) async {
          requests++;
          return response({
            'id': 7,
            'name': 'API title',
            'likeCount': 42,
            'score': 8.5,
            'dramas': [
              for (var i = 0; i < 6; i++)
                {'id': i + 1, 'needPay': i > 2 ? 1 : 0},
            ],
          });
        }),
      );
      final account = AccountStore(api: api);
      Widget page(int key) => AccountScope(
        store: account,
        child: MaterialApp(
          home: LiveDetail(
            key: ValueKey(key),
            drama: const DramaInfo(
              serverId: 7,
              title: 'Fallback title',
              image: 'battle-of-two-cities.png',
              genre: 'Fantasy',
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(1));
      await tester.pumpAndSettle();
      expect(find.byType(DetailPage), findsOneWidget);
      expect(find.text('API title'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('8.5/10'), findsOneWidget);
      expect(find.text('Watch Trailer'), findsOneWidget);
      expect(find.text(detailSynopsis), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('detail-scroll')),
        const Offset(0, -460),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail-cast')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-episodes')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('detail-recommendations')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(page(2));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('API title'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      account.dispose();
      api.dispose();
    },
  );
}
