import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelmax/src/startup.dart';

void main() {
  testWidgets(
    'startup waits for preparation, blocks input and keeps home mounted',
    (tester) async {
      final prepared = Completer<void>();
      final home = GlobalKey<_HomeProbeState>();
      var preparations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupGate(
            prepare: (_) {
              preparations++;
              return prepared.future;
            },
            child: _HomeProbe(key: home),
          ),
        ),
      );
      final state = home.currentState;
      expect(find.byKey(const ValueKey('startup-screen')), findsOneWidget);
      await tester.tap(find.text('Open home'), warnIfMissed: false);
      expect(state!.taps, 0);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.byKey(const ValueKey('startup-screen')), findsOneWidget);
      prepared.complete();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('startup-screen')), findsNothing);
      expect(home.currentState, same(state));
      await tester.tap(find.text('Open home'));
      expect(state.taps, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(preparations, 1);
      expect(find.byKey(const ValueKey('startup-screen')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed or stalled preparation cannot block launch', (
    tester,
  ) async {
    for (final pending in [false, true]) {
      final preparation = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: StartupGate(
            key: ValueKey(pending),
            prepare: (_) => pending
                ? preparation.future
                : Future.error(StateError('preview failure')),
            child: const Text('Home ready'),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('startup-screen')), findsNothing);
      expect(find.text('Home ready'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      if (pending) preparation.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'reduced motion skips the brand animation and early disposal is safe',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: StartupGate(
              prepare: (_) async {},
              child: const Text('Home ready'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('startup-screen')), findsNothing);
      final prepared = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: StartupGate(
            prepare: (_) => prepared.future,
            child: const Text('Home ready'),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      prepared.complete();
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('startup artwork fits phone sizes and exports visual previews', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final font = FontLoader('Commissioner')
      ..addFont(rootBundle.load('assets/fonts/Commissioner-Variable.ttf'));
    await font.load();
    for (final size in [const Size(390, 844), const Size(360, 640)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        const MaterialApp(
          home: RepaintBoundary(
            key: ValueKey('startup-capture'),
            child: StartupArtwork(),
          ),
        ),
      );
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('startup-capture')),
      );
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 1);
        final data = await picture.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'build/verification/startup-${size.width.toInt()}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        picture.dispose();
      });
      expect(tester.takeException(), isNull);
    }
  });
}

class _HomeProbe extends StatefulWidget {
  const _HomeProbe({super.key});
  @override
  State<_HomeProbe> createState() => _HomeProbeState();
}

class _HomeProbeState extends State<_HomeProbe> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => taps++),
      child: const Text('Open home'),
    ),
  );
}
