import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:reelmax/src/library_guest.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:reelmax/src/account_state.dart';
import 'package:reelmax/src/api.dart';
import 'package:reelmax/src/auth.dart';
import 'package:reelmax/src/live_catalog.dart';
import 'api_test.dart' show MemorySessionStorage, response;

void main() {
  testWidgets(
    'loading and empty library states are centered in remaining space',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final pending = Completer<http.Response>();
      final api = SkitApi(
        storage: MemorySessionStorage(),
        client: MockClient((r) => pending.future),
      );
      api.token = 'test-token';
      final account = AccountStore(api: api);
      await tester.pumpWidget(
        AccountScope(
          store: account,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: LiveListPage(
              title: 'List',
              path: 'skit/myCollectList',
              library: true,
              openDetail: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      void checkCenter() {
        final area = tester.getCenter(find.byType(LibraryStatus));
        final content = tester.getCenter(
          find.byKey(const ValueKey('library-status-content')),
        );
        expect(content.dx, closeTo(area.dx, 1));
        expect(content.dy, closeTo(area.dy, 1));
      }

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      checkCenter();
      pending.complete(response([]));
      await tester.pumpAndSettle();
      expect(find.text('Make room for great stories'), findsOneWidget);
      expect(find.text('No results yet.'), findsNothing);
      checkCenter();
      await tester.tap(find.text('Liked'));
      await tester.pumpAndSettle();
      expect(find.text('Your favorites start here'), findsOneWidget);
      checkCenter();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      account.dispose();
      api.dispose();
    },
  );

  testWidgets(
    'guest library has one sign-in invitation and no private requests',
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
      var requests = 0;
      final api = SkitApi(
        storage: MemorySessionStorage(),
        client: MockClient((r) async {
          requests++;
          return response([]);
        }),
      );
      final account = AccountStore(api: api);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: AccountScope(
            store: account,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData.dark(),
              home: LiveListPage(
                title: 'List',
                path: 'skit/myCollectList',
                library: true,
                openDetail: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(find.text('No results yet.'), findsNothing);
      expect(find.text('Your next favorite, saved.'), findsOneWidget);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/verification/library-guest.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.text('Liked'));
      await tester.pumpAndSettle();
      expect(find.text('Keep your favorites close.'), findsOneWidget);
      expect(requests, 0);
      await tester.tap(find.text('Sign in / Create account'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      account.dispose();
      api.dispose();
    },
  );
}
