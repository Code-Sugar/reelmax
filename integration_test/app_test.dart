import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reelmax/main.dart' as app;
import 'package:reelmax/src/design.dart';
import 'package:reelmax/src/media.dart';
import 'package:reelmax/src/account_state.dart';
import 'package:video_player/video_player.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: video, navigation, accounts, purchases and language', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();
    Future<void> waitForVideo() async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        final players = tester.widgetList<VideoPlayer>(
          find.byType(VideoPlayer),
        );
        if (players.any(
          (p) =>
              p.controller.value.isInitialized &&
              p.controller.value.position > Duration.zero,
        )) {
          return;
        }
      }
      fail('No decoded and advancing video after ten seconds.');
    }

    Finder label(String value) =>
        find.byWidgetPredicate((w) => w is Pressable && w.label == value);
    Future<void> tap(Finder finder) async {
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    void expectCompactHeader(Finder header) {
      final safeTop = MediaQuery.paddingOf(tester.element(header)).top;
      final gap = tester.getTopLeft(header).dy - safeTop;
      expect(
        gap,
        inInclusiveRange(8.0, 28.0),
        reason: 'Headers should sit just below the system status bar.',
      );
    }

    await waitForVideo();
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    expectCompactHeader(find.text('Reel Max'));
    await binding.takeScreenshot('today');
    await tap(find.text('Top'));
    await tap(find.byKey(const ValueKey('next-teaser')));
    await waitForVideo();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Redline'), findsOneWidget);
    await binding.takeScreenshot('today-redline');
    await tap(find.byKey(const ValueKey('hero-open')));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('detail-title'))).data,
      'Redline',
    );
    final detailPage = find.byKey(const ValueKey('detail-page'));
    final detailBounds = tester.getRect(detailPage);
    await tester.dragFrom(const Offset(240, 240), const Offset(-120, 160));
    await tester.pumpAndSettle();
    expect(detailPage, findsOneWidget);
    expect(tester.getRect(detailPage), detailBounds);
    expectCompactHeader(find.text('Reel Max').last);
    await binding.takeScreenshot('detail');
    await tester.drag(
      find.byKey(const ValueKey('detail-scroll')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-cast')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-episodes')), findsOneWidget);
    await binding.takeScreenshot('detail-content');
    await tap(find.byKey(const ValueKey('detail-episode-1')));
    expect(find.text('Episodes 04'), findsOneWidget);
    await tap(label('返回详情页'));
    await tester.drag(
      find.byKey(const ValueKey('detail-scroll')),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();
    await tap(label('Watch Trailer'));
    await waitForVideo();
    final player = tester
        .widgetList<VideoPlayer>(find.byType(VideoPlayer))
        .last
        .controller;
    expect(player.value.hasError, isFalse);
    await tap(label('暂停'));
    await player.seekTo(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(player.value.position.inMilliseconds, greaterThanOrEqualTo(1900));
    expectCompactHeader(label('返回详情页'));
    await binding.takeScreenshot('player');
    await tap(find.byKey(const ValueKey('player-collect')));
    expect(find.text('Saved'), findsOneWidget);
    await binding.takeScreenshot('player-saved');
    await tap(find.byKey(const ValueKey('player-quality')));
    for (final quality in ['720p', '1080p', '2K', '4K']) {
      expect(find.byKey(ValueKey('quality-option-$quality')), findsOneWidget);
    }
    await binding.takeScreenshot('player-quality');
    await tap(find.byKey(const ValueKey('quality-option-1080p')));
    expect(label('清晰度 1080p'), findsOneWidget);
    await binding.takeScreenshot('player-quality-1080p');
    expect(player.value.isPlaying, isFalse);
    expect(player.value.position.inMilliseconds, greaterThanOrEqualTo(1900));
    await tap(find.byKey(const ValueKey('player-list')));
    for (var number = 1; number <= 20; number++) {
      expect(find.byKey(ValueKey('episode-option-$number')), findsOneWidget);
      expect(
        find.byKey(ValueKey('episode-lock-$number')),
        number > 5 ? findsOneWidget : findsNothing,
      );
    }
    await binding.takeScreenshot('player-episodes');
    await tap(find.byKey(const ValueKey('episode-option-20')));
    expect(find.text('Episode 20 is locked'), findsOneWidget);
    expect(find.byKey(const ValueKey('episode-panel')), findsOneWidget);
    await tap(find.byKey(const ValueKey('episode-option-1')));
    expect(find.text('Episodes 01'), findsOneWidget);
    await tap(find.byKey(const ValueKey('player-list')));
    await tap(find.byKey(const ValueKey('episode-option-3')));
    expect(find.text('Episodes 03'), findsOneWidget);
    await tap(label('暂停'));
    await player.seekTo(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    final heading = tester
        .widget<Text>(
          find.byWidgetPredicate(
            (w) => w is Text && (w.data ?? '').startsWith('Episodes '),
          ),
        )
        .data!;
    final before = int.parse(heading.split(' ').last);
    final expected = before % 5 + 1;
    final viewport = tester.getRect(find.byKey(const ValueKey('player-swipe')));
    final fullDrag = await tester.startGesture(
      Offset(
        viewport.left + viewport.width * .25,
        viewport.top + viewport.height * .85,
      ),
    );
    await fullDrag.moveBy(const Offset(0, -24));
    await tester.pump();
    final videoFrame = find.descendant(
      of: find.byKey(const ValueKey('player-current-video')),
      matching: find.byType(VideoCover),
    );
    final dragStart = tester.getTopLeft(videoFrame).dy;
    await fullDrag.moveBy(Offset(0, -viewport.height * .35));
    await tester.pump();
    await fullDrag.moveBy(Offset(0, -viewport.height * .3));
    await tester.pump();
    expect(
      tester.getTopLeft(videoFrame).dy,
      closeTo(dragStart - viewport.height * .65, 1),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await binding.takeScreenshot('player-full-drag');
    await fullDrag.up();
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find
          .text('Episodes ${expected.toString().padLeft(2, '0')}')
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(
      find.text('Episodes ${expected.toString().padLeft(2, '0')}'),
      findsOneWidget,
    );
    await tap(label('返回详情页'));
    await tap(label('返回上一页'));
    await tap(find.byKey(const ValueKey('tab-1')));
    expectCompactHeader(find.text('Reel Max'));
    await binding.takeScreenshot('category');
    await tap(find.byKey(const ValueKey('category-history-fight-club.png')));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('detail-title'))).data,
      'My Sister Covets',
    );
    await tap(label('返回上一页'));
    await tap(find.byKey(const ValueKey('tab-2')));
    expectCompactHeader(find.text('list'));
    await binding.takeScreenshot('library');
    await tap(label('打开 My Sister Covets MyFiancé').first);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('detail-title'))).data,
      'My Sister Covets MyFiancé',
    );
    await tap(label('返回上一页'));
    await tap(find.byKey(const ValueKey('tab-3')));
    await tap(find.byKey(const ValueKey('profile-search')));
    expectCompactHeader(find.text('DISCOVER'));
    await binding.takeScreenshot('search');
    await tester.enterText(find.byKey(const ValueKey('search-input')), 'red');
    await tester.pumpAndSettle();
    expect(find.text('Redline'), findsOneWidget);
    expect(find.text('Neon Drift'), findsNothing);
    await tap(label('打开 Redline'));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('detail-title'))).data,
      'Redline',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-page')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('search-input')))
          .controller!
          .text,
      'red',
    );
    Future<void> accountTap(String key) async {
      final target = find.byKey(ValueKey(key));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tap(target);
    }

    Future<void> accountEnter(String key, String value) async {
      final target = find.byKey(ValueKey(key));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.enterText(target, value);
      await tester.pumpAndSettle();
    }

    Future<void> back() async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    await back();
    await capture('profile-guest');
    await accountTap('profile-sign-in');
    await capture('auth-login');
    await accountTap('auth-switch');
    await accountEnter('auth-name', 'Alex Morgan');
    await accountEnter('auth-email', 'mumu@example.com');
    await accountEnter('auth-password', 'demoPass123');
    await accountEnter('auth-confirm', 'demoPass123');
    await accountTap('auth-submit');
    final store = AccountScope.of(
      tester.element(find.byKey(const ValueKey('profile-name'))),
    );
    expect(store.user?.balance, 100);
    await capture('profile-signed-in');
    await accountTap('profile-top-up');
    await capture('store-coins');
    await accountTap('store-continue');
    await capture('checkout');
    await accountTap('checkout-method-1');
    await accountTap('checkout-pay');
    expect(find.byKey(const ValueKey('purchase-success')), findsOneWidget);
    expect(store.user?.balance, 1200);
    expect(store.user?.orders.length, 1);
    await capture('payment-success');
    await accountTap('purchase-done');
    await back();
    await accountTap('profile-orders');
    expect(
      find.byKey(ValueKey('order-${store.user!.orders.first.id}')),
      findsOneWidget,
    );
    await capture('orders');
    await back();
    await accountTap('profile-coin-history');
    expect(find.text('+1,000'), findsOneWidget);
    await capture('coin-history');
    await back();
    await accountTap('profile-plus');
    await capture('store-membership');
    await accountTap('store-continue');
    await accountTap('checkout-pay');
    expect(store.plus, isTrue);
    expect(store.user?.orders.length, 2);
    await accountTap('purchase-done');
    await back();
    await accountTap('profile-language');
    await accountTap('language-zh');
    expect(store.chinese, isTrue);
    await capture('language-chinese');
    await back();
    await tester.drag(
      find.byKey(const ValueKey('profile-scroll')),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    await capture('profile-member-chinese');
    await accountTap('profile-language');
    await accountTap('language-en');
    await back();
    expect(tester.takeException(), isNull);
  });
}
