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
import 'api_test.dart' show MemorySessionStorage, response;

void main() {
  setUp(() async {
    final font = FontLoader('Commissioner')
      ..addFont(rootBundle.load('assets/fonts/Commissioner-Variable.ttf'));
    await font.load();
  });
  testWidgets(
    'live catalog preserves reference sections when API modules do not match',
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
      expect(find.text('Hot New'), findsOneWidget);
      expect(find.text('unmapped'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      account.dispose();
      api.dispose();
    },
  );

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
