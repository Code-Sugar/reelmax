import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:reelmax/src/account_state.dart';
import 'package:reelmax/src/api.dart';
import 'package:reelmax/src/design.dart';
import 'package:reelmax/src/live_category.dart';
import 'api_test.dart' show MemorySessionStorage, response;

void main() {
  testWidgets(
    'catalog uses reference poster proportions and one recommendation title',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await (FontLoader(
            'Commissioner',
          )..addFont(rootBundle.load('assets/fonts/Commissioner-Variable.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final rows = [
        {'id': 1, 'name': 'Love Scout', 'cover': 'poster-love-scout.png'},
        {
          'id': 2,
          'name': 'One of Them Days',
          'cover': 'poster-one-of-them-days.png',
        },
        {'id': 3, 'name': 'Steve', 'cover': 'poster-steve.png'},
      ];
      final api = SkitApi(
        storage: MemorySessionStorage(),
        client: MockClient(
          (r) async => response({
            'init': [
              {
                'id': 1,
                'title': 'Recommended',
                'module': [
                  {
                    'id': 1,
                    'style': 1,
                    'title': 'Drama Library',
                    'subtitle': 'Drama Library',
                    'more': 1,
                    'skits': rows,
                  },
                  {'id': 2, 'style': 2, 'title': 'Watchlist', 'skits': rows},
                ],
              },
            ],
          }),
        ),
      );
      final account = AccountStore(api: api);
      for (final r in rows) {
        await account.watchHistory.record('guest', {
          'skitId': r['id'],
          'dramaId': r['id'],
          'skitName': r['name'],
          'cover': r['cover'],
          'episodeTitle': 'Episode 2',
          'positionMs': 77000,
          'durationMs': 155000,
        });
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: AccountScope(
            store: account,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData.dark(),
              home: Scaffold(body: LiveCategory(openDetail: (_) {})),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(LiveCategory));
        for (final row in rows) {
          await precacheImage(AssetImage('assets/${row['cover']}'), context);
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Drama Library'), findsOneWidget);
      final history = find.byKey(const ValueKey('history-3-3'));
      final cover = tester.getSize(
        find.descendant(of: history, matching: find.byType(Art)),
      );
      expect(cover.height / cover.width, closeTo(151 / 104, .001));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/verification/category-layout.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      account.dispose();
      api.dispose();
    },
  );
}
