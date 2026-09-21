import 'package:reelmax/src/home.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelmax/src/app.dart';
import 'package:reelmax/src/design.dart';
import 'package:reelmax/src/data.dart';
import 'package:reelmax/src/media.dart';
import 'package:reelmax/src/player_panels.dart';
import 'package:reelmax/src/account_state.dart';
import 'package:reelmax/src/profile.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'support/fake_video.dart';

// Screenshot comparisons need the same soft shadows as the running app.
class _VisualTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _VisualTestBinding();
  late FakeVideoPlatform video;
  setUp(() {
    video = FakeVideoPlatform();
    VideoPlayerPlatform.instance = video;
  });
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      debugDefaultTargetPlatformOverride = null;
    });
    final loader = FontLoader('Commissioner')
      ..addFont(rootBundle.load('assets/fonts/Commissioner-Variable.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await tester.pumpWidget(
      const RepaintBoundary(
        key: ValueKey('capture'),
        child: ReelMaxApp(demo: true),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ReelMaxApp));
    await tester.runAsync(() async {
      for (final file in Directory('assets').listSync().whereType<File>()) {
        if (file.path.endsWith('.png') || file.path.endsWith('.jpg')) {
          await precacheImage(
            AssetImage(file.path.replaceAll('\\', '/')),
            context,
          );
        }
      }
      for (final bytes in video.frames.values) {
        await precacheImage(MemoryImage(bytes), context);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 1);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/verification/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> accountTap(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tap(tester, target);
  }

  Future<void> accountEnter(
    WidgetTester tester,
    String key,
    String value,
  ) async {
    final target = find.byKey(ValueKey(key));
    await tester.ensureVisible(target);
    await tester.enterText(target, value);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Finder label(String text) =>
      find.byWidgetPredicate((w) => w is Pressable && w.label == text);
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('tab cache retains category position and genre selection', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.byKey(const ValueKey('tab-1')));
    await tap(tester, find.text('Action'));
    final category = find.byKey(const ValueKey('category-scroll'));
    await tester.drag(category, const Offset(0, -420));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: category, matching: find.byType(Scrollable)).first,
    );
    final offset = scroll.position.pixels;
    expect(offset, greaterThan(100));
    await tap(tester, find.byKey(const ValueKey('tab-3')));
    await tap(tester, find.byKey(const ValueKey('tab-1')));
    final restored = tester.state<ScrollableState>(
      find.descendant(of: category, matching: find.byType(Scrollable)).first,
    );
    expect(identical(scroll, restored), isTrue);
    expect(restored.position.pixels, offset);
    final action = tester.widget<Pressable>(
      find
          .ancestor(of: find.text('Action'), matching: find.byType(Pressable))
          .first,
    );
    expect(action.selected, isTrue);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets(
    'reference tour: tabs, filters, Next, details, player, search and list',
    (tester) async {
      await mount(tester);
      expect(find.text('Battle Of Two Cities'), findsOneWidget);
      await shot(tester, '01-today');
      await tap(tester, find.text('Top'));
      expect(find.text('已切换到 Top'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('next-teaser')));
      expect(find.text('Redline'), findsOneWidget);
      await shot(tester, '01b-today-redline');
      await tap(tester, find.byKey(const ValueKey('next-collapse')));
      await tester.drag(
        find.byKey(const ValueKey('hero-open')),
        const Offset(0, -140),
      );
      await tester.pumpAndSettle();
      expect(find.text('Battle Of Two Cities'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('next-expand')));
      await tap(tester, find.byKey(const ValueKey('hero-open')));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('detail-title'))).data,
        'Battle Of Two Cities',
      );
      final detailPage = find.byKey(const ValueKey('detail-page'));
      final beforeDrag = tester.getRect(detailPage);
      final gesture = await tester.startGesture(const Offset(230, 240));
      await gesture.moveBy(const Offset(-120, 190));
      await tester.pump();
      expect(tester.getRect(detailPage), beforeDrag);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(detailPage, findsOneWidget);
      expect(tester.getRect(detailPage), beforeDrag);
      await shot(tester, '02-detail');
      await tap(tester, label('喜欢'));
      expect(find.text('1365'), findsOneWidget);
      await tap(tester, label('Watch Trailer'));
      expect(find.text('Episodes 03'), findsOneWidget);
      await shot(tester, '03-player');
      await tap(tester, find.byKey(const ValueKey('player-collect')));
      expect(find.text('Saved'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('player-like')));
      await tap(tester, find.byKey(const ValueKey('player-list')));
      expect(find.byKey(const ValueKey('episode-panel')), findsOneWidget);
      await tap(tester, label('关闭Episodes'));
      await tester.dragFrom(const Offset(110, 430), const Offset(0, -130));
      await tester.pumpAndSettle();
      expect(find.text('Episodes 04'), findsOneWidget);
      expect(find.text('已切换到下一集'), findsNothing);
      expect(find.text('下滑切换剧集'), findsNothing);
      await tester.tapAt(const Offset(175, 410));
      await tester.pumpAndSettle();
      expect(label('播放'), findsOneWidget);
      await tester.tapAt(const Offset(280, 816));
      await tester.pumpAndSettle();
      expect(video.positions.values.any((p) => p.inSeconds > 10), isTrue);
      await tap(tester, label('返回详情页'));
      await tap(tester, label('返回上一页'));
      await tap(tester, find.byKey(const ValueKey('tab-1')));
      expect(find.text('Explore Genres'), findsOneWidget);
      await shot(tester, '04-category');
      await tester.drag(
        find.byKey(const ValueKey('category-scroll')),
        const Offset(0, -620),
      );
      await tester.pumpAndSettle();
      await shot(tester, '05-category-more');
      await tap(tester, find.byKey(const ValueKey('tab-2')));
      expect(find.text('78% · Episode 1'), findsWidgets);
      await shot(tester, '06-history');
      await tap(tester, find.text('Collect'));
      expect(find.text('18.6K'), findsOneWidget);
      await shot(tester, '07-collect');
      await tap(tester, find.byKey(const ValueKey('list-edit')));
      await tap(tester, label('移除 My Sister Covets MyFiancé').first);
      expect(find.text('18.6K'), findsNothing);
      await tap(tester, find.text('History'));
      await tester.drag(
        label('打开 My Sister Covets MyFiancé').first,
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();
      await shot(tester, '08-list-swipe');
      await tap(tester, label('删除 My Sister Covets MyFiancé').first);
      expect(find.text('78% · Episode 1'), findsNWidgets(3));
      await tap(tester, find.byKey(const ValueKey('tab-3')));
      await tap(tester, find.byKey(const ValueKey('profile-search')));
      await shot(tester, '09-search');
      await tester.enterText(find.byKey(const ValueKey('search-input')), 'red');
      await tester.pumpAndSettle();
      expect(find.text('Redline'), findsOneWidget);
      expect(find.text('Afterlight'), findsNothing);
      await tap(tester, label('清空搜索'));
      expect(find.text('Afterlight'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets(
    'every drama card opens its own detail and returns to its source',
    (tester) async {
      await mount(tester);
      void expectDrama(String title, String image) {
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('detail-title'))).data,
          title,
        );
        expect(
          tester.widget<Art>(find.byKey(const ValueKey('detail-poster'))).name,
          image,
        );
      }

      Future<void> visit(
        Finder card,
        String title,
        String image, {
        bool bottomEdge = false,
      }) async {
        await Scrollable.ensureVisible(tester.element(card), alignment: .3);
        await tester.pumpAndSettle();
        if (bottomEdge) {
          final box = tester.getRect(card);
          await tester.tapAt(Offset(box.center.dx, box.bottom - 8));
          await tester.pumpAndSettle();
        } else {
          await tap(tester, card);
        }
        expectDrama(title, image);
        await tap(tester, label('返回上一页'));
        expect(find.byKey(const ValueKey('detail-page')), findsNothing);
      }

      await tap(tester, find.byKey(const ValueKey('hero-open')));
      expectDrama(features[0].title, features[0].image);
      await tap(tester, label('喜欢'));
      await tap(tester, label('返回上一页'));
      await tap(tester, find.byKey(const ValueKey('next-teaser')));
      await tap(tester, find.byKey(const ValueKey('hero-open')));
      expectDrama(features[1].title, features[1].image);
      expect(label('喜欢'), findsOneWidget);
      await tap(tester, label('喜欢'));
      await tap(tester, label('返回上一页'));

      await tap(tester, find.byKey(const ValueKey('tab-1')));
      for (final asset in [
        'history-fight-club.png',
        'history-fashion.png',
        'history-crowd.png',
      ]) {
        await visit(
          find.byKey(ValueKey('category-$asset')),
          'My Sister Covets',
          asset,
        );
      }
      for (final (title, asset) in [
        ('Love Scout', 'poster-love-scout.png'),
        ('One of Them Days', 'poster-one-of-them-days.png'),
        ('Steve', 'poster-steve.png'),
        ('Obsession', 'poster-obsession.png'),
        ('Then You Run', 'poster-then-you-run.png'),
        ('The Best Horror Movie', 'poster-horror.png'),
      ]) {
        await visit(
          label(title),
          title,
          asset,
          bottomEdge: title == 'Love Scout',
        );
      }
      for (final asset in [
        'poster-film-yourself.png',
        'poster-agent-husband.png',
        'poster-john-wick.png',
      ]) {
        await visit(
          find.byKey(ValueKey('category-$asset')),
          'My Sister Covets',
          asset,
        );
      }
      for (final (title, asset) in [
        ('The Chosen One', 'poster-chosen-one.png'),
        ('Greendale', 'poster-greendale.png'),
        ('Euphoria', 'euphoria-cover.png'),
        ('Fight Club', 'fight-club-cover.jpg'),
      ]) {
        for (
          var attempt = 0;
          label(title).evaluate().isEmpty && attempt < 4;
          attempt++
        ) {
          await tester.drag(
            find.byKey(const ValueKey('cinema-scroll')),
            const Offset(-220, 0),
          );
          await tester.pumpAndSettle();
        }
        await visit(label(title), title, asset);
      }
      await visit(
        label('Unlimited Drama'),
        'Unlimited Drama',
        'unlimited-drama-art.png',
      );

      await tap(tester, find.byKey(const ValueKey('tab-2')));
      for (var i = 0; i < history.length; i++) {
        await visit(
          label('打开 ${history[i].title}').at(i),
          history[i].title,
          history[i].image,
        );
      }
      await tap(tester, find.text('Collect'));
      for (var i = 0; i < collected.length; i++) {
        await visit(
          label('打开 ${collected[i].title}').at(i),
          collected[i].title,
          collected[i].image,
        );
      }
      await tap(tester, find.byKey(const ValueKey('tab-3')));
      await tap(tester, find.byKey(const ValueKey('profile-search')));
      for (final drama in searchDramas) {
        await visit(label('打开 ${drama.title}'), drama.title, drama.image);
      }
      await tester.enterText(find.byKey(const ValueKey('search-input')), 'red');
      await tester.pumpAndSettle();
      await tap(tester, label('打开 Redline'));
      expect(label('取消喜欢'), findsOneWidget);
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
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets('detail shows fixed content and opens the selected episode', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.byKey(const ValueKey('hero-open')));
    final synopsis = tester.widget<Text>(
      find.byKey(const ValueKey('detail-synopsis')),
    );
    expect(synopsis.data!.length, greaterThan(160));
    await tap(tester, find.text('More'));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('detail-synopsis')))
          .maxLines,
      isNull,
    );
    await tap(tester, find.text('Less'));
    await tester.drag(
      find.byKey(const ValueKey('detail-scroll')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-cast')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('detail-recommendations')),
      findsOneWidget,
    );
    await shot(tester, '02b-detail-content');
    await tap(tester, find.byKey(const ValueKey('detail-episode-1')));
    expect(find.text('Episodes 04'), findsOneWidget);
    await tap(tester, label('返回详情页'));
    expect(find.byKey(const ValueKey('detail-episodes')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('cold start tolerates an initially empty Android surface', (
    tester,
  ) async {
    await mount(tester, size: Size.zero);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.text('Battle Of Two Cities'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('home swipes only with Next collapsed and settles continuously', (
    tester,
  ) async {
    await mount(tester);
    Finder video(int index) => find.descendant(
      of: find.byKey(ValueKey('home-video-$index')),
      matching: find.byType(PreviewVideo),
    );
    await tester.drag(
      find.byKey(const ValueKey('home-swipe')),
      const Offset(0, -540),
    );
    await tester.pumpAndSettle();
    expect(find.text('Battle Of Two Cities'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('next-collapse')));
    final gesture = await tester.startGesture(const Offset(110, 740));
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    final start = tester.getTopLeft(video(0)).dy;
    await gesture.moveBy(const Offset(0, -240));
    await tester.pump();
    expect(tester.getTopLeft(video(0)).dy, closeTo(start - 240, .1));
    await gesture.moveBy(const Offset(0, -280));
    await tester.pump();
    final beforeRelease = tester.getTopLeft(video(0)).dy;
    expect(beforeRelease, closeTo(start - 520, .1));
    expect(
      tester.getBottomLeft(video(0)).dy,
      closeTo(tester.getTopLeft(video(1)).dy, .1),
    );
    await gesture.up();
    await tester.pump();
    expect(tester.getTopLeft(video(0)).dy, closeTo(beforeRelease, .1));
    await tester.pumpAndSettle();
    expect(find.text('Redline'), findsOneWidget);

    // A vertical drag beginning on a filter still changes the video.
    final reverse = await tester.startGesture(
      tester.getCenter(find.text('Top')),
    );
    await reverse.moveBy(const Offset(0, 24));
    await tester.pump();
    await reverse.moveBy(const Offset(0, 540));
    await tester.pump();
    expect(tester.getTopLeft(video(1)).dy, greaterThan(500));
    await reverse.up();
    await tester.pumpAndSettle();
    expect(find.text('Battle Of Two Cities'), findsOneWidget);
    expect(find.text('已切换到 Top'), findsNothing);

    final canceled = await tester.startGesture(const Offset(110, 500));
    await canceled.moveBy(const Offset(0, -24));
    await tester.pump();
    await canceled.moveBy(const Offset(0, -40));
    await tester.pump();
    await canceled.cancel();
    await tester.pump();
    expect(tester.getTopLeft(video(0)).dy, lessThan(0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(video(0)).dy, closeTo(0, .1));
    expect(find.text('Battle Of Two Cities'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('expanded Next advances on tap with a slower zoom transition', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('next-teaser')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final dynamic state = tester.state(find.byType(HomePage));
    expect(state.expanding, isTrue);
    expect(state.feature, 0);
    // Repeated taps during expansion must not skip another video.
    await tester.tap(find.byKey(const ValueKey('next-teaser')));
    await tester.pumpAndSettle();
    expect(state.expanding, isFalse);
    expect(state.feature, 1);
    expect(find.text('Redline'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets(
    'player drags across a full screen from controls, reverses and auto-advances',
    (tester) async {
      await mount(tester);
      await tap(tester, find.byKey(const ValueKey('hero-open')));
      await tap(tester, label('Watch Trailer'));
      Finder videoFrame(String name) => find.descendant(
        of: find.byKey(ValueKey('player-$name-video')),
        matching: find.byType(VideoCover),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('player-like'))),
      );
      await gesture.moveBy(const Offset(0, -24));
      await tester.pump();
      final start = tester.getTopLeft(videoFrame('current')).dy;
      await gesture.moveBy(const Offset(0, -240));
      await tester.pump();
      expect(
        tester.getTopLeft(videoFrame('current')).dy,
        closeTo(start - 240, .1),
      );
      await gesture.moveBy(const Offset(0, -280));
      await tester.pump();
      final beforeRelease = tester.getTopLeft(videoFrame('current')).dy;
      expect(beforeRelease, closeTo(start - 520, .1));
      expect(
        tester.getBottomLeft(videoFrame('current')).dy,
        closeTo(tester.getTopLeft(videoFrame('adjacent')).dy, .1),
      );
      await gesture.up();
      await tester.pump();
      expect(
        tester.getTopLeft(videoFrame('current')).dy,
        closeTo(beforeRelease, .1),
      );
      await tester.pumpAndSettle();
      expect(find.text('Episodes 04'), findsOneWidget);
      expect(
        tester
            .widget<Pressable>(find.byKey(const ValueKey('player-like')))
            .selected,
        isFalse,
      );

      await tester.dragFrom(const Offset(110, 180), const Offset(0, 560));
      await tester.pumpAndSettle();
      expect(find.text('Episodes 03'), findsOneWidget);
      final shortDrag = await tester.startGesture(const Offset(110, 500));
      await shortDrag.moveBy(const Offset(0, -24));
      await tester.pump();
      await shortDrag.moveBy(const Offset(0, -30));
      await tester.pump();
      await shortDrag.up();
      await tester.pumpAndSettle();
      expect(find.text('Episodes 03'), findsOneWidget);
      expect(tester.getTopLeft(videoFrame('current')).dy, closeTo(0, .1));
      final currentId = video.playing.entries
          .singleWhere((entry) => entry.value)
          .key;
      video.complete(currentId);
      await tester.pumpAndSettle();
      expect(find.text('Episodes 04'), findsOneWidget);
      expect(video.playing.values.where((playing) => playing), hasLength(1));
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets(
    'collection uses yellow feedback and episode sheet enforces its locks',
    (tester) async {
      await mount(tester);
      await tap(tester, find.byKey(const ValueKey('hero-open')));
      await tap(tester, label('Watch Trailer'));
      final collect = find.byKey(const ValueKey('player-collect'));
      await tap(tester, collect);
      expect(tester.widget<Pressable>(collect).selected, isTrue);
      final bookmark = tester.widget<Glyph>(
        find.descendant(of: collect, matching: find.byType(Glyph)),
      );
      expect(bookmark.name, 'bookmark-active');
      expect(bookmark.color, collectionYellow);
      await shot(tester, '12-player-saved');
      await tap(tester, find.byKey(const ValueKey('player-list')));
      expect(find.byKey(const ValueKey('episode-panel')), findsOneWidget);
      expect(video.playing.values.where((playing) => playing), isEmpty);
      for (var number = 1; number <= 20; number++) {
        expect(find.byKey(ValueKey('episode-option-$number')), findsOneWidget);
        expect(
          find.byKey(ValueKey('episode-lock-$number')),
          number > 5 ? findsOneWidget : findsNothing,
        );
      }
      expect(
        tester
            .widget<Pressable>(find.byKey(const ValueKey('episode-option-3')))
            .selected,
        isTrue,
      );
      await shot(tester, '13-player-episodes');
      await tap(tester, find.byKey(const ValueKey('episode-option-20')));
      expect(find.text('Episode 20 is locked'), findsOneWidget);
      expect(find.text('Episodes 03'), findsOneWidget);
      expect(find.byKey(const ValueKey('episode-panel')), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('episode-option-1')));
      expect(find.byKey(const ValueKey('episode-panel')), findsNothing);
      expect(find.text('Episodes 01'), findsOneWidget);
      expect(video.playing.values.where((playing) => playing), hasLength(1));
      await tap(tester, find.byKey(const ValueKey('player-list')));
      expect(
        tester
            .widget<Pressable>(find.byKey(const ValueKey('episode-option-1')))
            .selected,
        isTrue,
      );
      await tap(tester, find.byKey(const ValueKey('episode-option-5')));
      expect(find.text('Episodes 05'), findsOneWidget);
      await tester.dragFrom(const Offset(110, 680), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Episodes 01'), findsOneWidget);
      await tap(tester, collect);
      expect(tester.widget<Pressable>(collect).selected, isFalse);
      expect(
        tester
            .widget<Glyph>(
              find.descendant(of: collect, matching: find.byType(Glyph)),
            )
            .name,
        'player-bookmark',
      );
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets(
    'quality options remember selection and sheets preserve paused playback',
    (tester) async {
      await mount(tester);
      await tap(tester, find.byKey(const ValueKey('hero-open')));
      await tap(tester, label('Watch Trailer'));
      await tap(tester, label('暂停'));
      final controller = tester
          .widget<VideoCover>(
            find.descendant(
              of: find.byKey(const ValueKey('player-current-video')),
              matching: find.byType(VideoCover),
            ),
          )
          .controller;
      await controller.seekTo(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      var selected = '4K';
      for (final quality in playerQualities) {
        await tap(tester, find.byKey(const ValueKey('player-quality')));
        expect(find.byKey(const ValueKey('quality-panel')), findsOneWidget);
        expect(
          tester
              .widget<Pressable>(
                find.byKey(ValueKey('quality-option-$selected')),
              )
              .selected,
          isTrue,
        );
        for (final option in playerQualities) {
          expect(
            find.byKey(ValueKey('quality-option-$option')),
            findsOneWidget,
          );
        }
        if (quality == '720p') await shot(tester, '14-player-quality');
        await tap(tester, find.byKey(ValueKey('quality-option-$quality')));
        expect(find.byKey(const ValueKey('quality-panel')), findsNothing);
        expect(label('清晰度 $quality'), findsOneWidget);
        if (quality == '1080p') await shot(tester, '14b-player-quality-1080p');
        expect(controller.value.position, const Duration(seconds: 9));
        expect(controller.value.isPlaying, isFalse);
        selected = quality;
      }
      await tap(tester, find.byKey(const ValueKey('player-list')));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('episode-panel')), findsNothing);
      expect(find.text('Episodes 03'), findsOneWidget);
      expect(controller.value.isPlaying, isFalse);
      await tap(tester, label('播放'));
      await tap(tester, find.byKey(const ValueKey('player-quality')));
      await tester.tapAt(const Offset(100, 100));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quality-panel')), findsNothing);
      expect(controller.value.isPlaying, isTrue);
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets('player sheets fit a narrow phone with a bottom safe area', (
    tester,
  ) async {
    await mount(tester, size: const Size(360, 640));
    tester.view.padding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPadding);
    await tap(tester, find.byKey(const ValueKey('hero-open')));
    await tap(tester, label('Watch Trailer'));
    for (final control in ['list', 'quality']) {
      await tap(tester, find.byKey(ValueKey('player-$control')));
      expect(tester.takeException(), isNull);
      final panel = find.byType(PlayerPanel);
      expect(tester.getRect(panel).top, greaterThanOrEqualTo(36));
      expect(tester.getRect(panel).bottom, lessThanOrEqualTo(640));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    await finish(tester);
  });

  testWidgets(
    'account forms support registration, recovery and both social previews',
    (tester) async {
      await mount(tester);
      await tap(tester, find.byKey(const ValueKey('tab-3')));
      await shot(tester, '20-profile-guest');
      await accountTap(tester, 'profile-sign-in');
      await shot(tester, '21-auth-login');
      await accountTap(tester, 'auth-submit');
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await accountTap(tester, 'auth-switch');
      await accountEnter(tester, 'auth-name', 'Demo Viewer');
      await accountEnter(tester, 'auth-email', 'viewer@example.com');
      await accountEnter(tester, 'auth-password', 'demoPass123');
      await accountEnter(tester, 'auth-confirm', 'wrongPassword');
      await accountTap(tester, 'auth-submit');
      expect(find.text('The passwords do not match.'), findsOneWidget);
      await accountEnter(tester, 'auth-confirm', 'demoPass123');
      await shot(tester, '22-auth-register');
      await accountTap(tester, 'auth-submit');
      final store = AccountScope.of(
        tester.element(find.byKey(const ValueKey('profile-name'))),
      );
      expect(store.user?.name, 'Demo Viewer');
      expect(store.user?.balance, 100);
      expect(store.user?.orders, isEmpty);
      await accountTap(tester, 'profile-sign-out');
      await accountTap(tester, 'profile-sign-in');
      await accountTap(tester, 'auth-forgot');
      await accountEnter(tester, 'auth-email', 'viewer@example.com');
      await shot(tester, '23-auth-recover');
      await accountTap(tester, 'auth-submit');
      expect(
        find.text('Demo code: 123456. No email was sent.'),
        findsOneWidget,
      );
      await accountEnter(tester, 'auth-code', '000000');
      await accountEnter(tester, 'auth-password', 'newDemo123');
      await accountEnter(tester, 'auth-confirm', 'newDemo123');
      await accountTap(tester, 'auth-submit');
      expect(find.text('Use the demo code 123456.'), findsOneWidget);
      await accountEnter(tester, 'auth-code', '123456');
      await shot(tester, '24-auth-reset');
      await accountTap(tester, 'auth-submit');
      await accountTap(tester, 'auth-reset-done');
      await accountEnter(tester, 'auth-password', 'newDemo123');
      await accountTap(tester, 'auth-submit');
      expect(store.user?.name, 'Demo Viewer');
      for (final provider in ['google', 'facebook']) {
        await accountTap(tester, 'profile-sign-out');
        await accountTap(tester, 'profile-sign-in');
        await accountTap(tester, 'auth-$provider');
        expect(find.text('Alex Morgan'), findsOneWidget);
        await tap(tester, find.byKey(const ValueKey('social-demo-confirm')));
        expect(store.user?.provider.toLowerCase(), provider);
      }
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets(
    'coin checkout signs in, prevents duplicate purchases and updates both records',
    (tester) async {
      await mount(tester);
      await tap(tester, find.byKey(const ValueKey('tab-3')));
      await accountTap(tester, 'profile-top-up');
      await shot(tester, '27-store-coins');
      await accountTap(tester, 'store-continue');
      await accountEnter(tester, 'auth-email', 'buyer@example.com');
      await accountEnter(tester, 'auth-password', 'demoPass123');
      await accountTap(tester, 'auth-submit');
      expect(find.text('Checkout'), findsOneWidget);
      await accountTap(tester, 'checkout-method-1');
      await shot(tester, '28-checkout');
      final store = AccountScope.of(
        tester.element(find.byKey(const ValueKey('checkout-pay'))),
      );
      final previousOrders = store.user!.orders.length;
      await tester.tap(find.byKey(const ValueKey('checkout-pay')));
      await tester.tap(find.byKey(const ValueKey('checkout-pay')));
      await tester.pumpAndSettle();
      expect(store.user?.balance, 1220);
      expect(store.user!.orders.length, previousOrders + 1);
      expect(store.user!.orders.first.method, 'Google Pay');
      expect(store.user!.coins.first.balance, 1220);
      expect(store.user!.coins.first.amount, 100);
      expect(find.byKey(const ValueKey('purchase-success')), findsOneWidget);
      await shot(tester, '29-payment-success');
      await accountTap(tester, 'purchase-done');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('store-balance'))).data,
        '1,220',
      );
      await back(tester);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('profile-balance'))).data,
        '1,220',
      );
      await accountTap(tester, 'profile-orders');
      await shot(tester, '30-orders');
      await accountTap(tester, 'order-${store.user!.orders.first.id}');
      expect(find.text('Google Pay'), findsOneWidget);
      await shot(tester, '30b-order-details');
      await back(tester);
      await tap(tester, find.text('Membership'));
      expect(find.text('No orders yet'), findsOneWidget);
      await back(tester);
      await accountTap(tester, 'profile-coin-history');
      await shot(tester, '31-coin-history');
      await tap(tester, find.text('Spent'));
      expect(find.text('Episode unlocks'), findsOneWidget);
      expect(find.text('Bonus coins'), findsNothing);
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets(
    'subscription enables all episodes and language changes across the app',
    (tester) async {
      await mount(tester);
      await tap(tester, find.byKey(const ValueKey('tab-3')));
      final store = AccountScope.of(
        tester.element(find.byKey(const ValueKey('profile-name'))),
      );
      store.signIn('member@example.com', name: 'Alex Morgan');
      await tester.pumpAndSettle();
      await shot(tester, '25-profile-signed-in');
      await accountTap(tester, 'profile-plus');
      await shot(tester, '26-store-membership');
      await accountTap(tester, 'store-continue');
      await accountTap(tester, 'checkout-pay');
      expect(store.plus, isTrue);
      expect(store.user?.subscription?.id, 'yearly');
      expect(
        store.user!.expires!.difference(DateTime.now()).inDays,
        greaterThanOrEqualTo(364),
      );
      await accountTap(tester, 'purchase-done');
      expect(find.text('Current plan'), findsOneWidget);
      await back(tester);
      expect(find.text('ACTIVE'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('tab-0')));
      await tap(tester, find.byKey(const ValueKey('hero-open')));
      await tap(tester, label('Watch Trailer'));
      await tap(tester, find.byKey(const ValueKey('player-list')));
      expect(find.byKey(const ValueKey('episode-lock-20')), findsNothing);
      await accountTap(tester, 'episode-option-20');
      expect(find.text('Episodes 20'), findsOneWidget);
      await back(tester);
      await back(tester);
      await tap(tester, find.byKey(const ValueKey('tab-3')));
      await accountTap(tester, 'profile-language');
      await shot(tester, '32-language');
      await accountTap(tester, 'language-zh');
      expect(
        find.descendant(
          of: find.byType(LanguagePage),
          matching: find.text('应用语言'),
        ),
        findsOneWidget,
      );
      await back(tester);
      expect(find.text('订单记录'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('tab-0')));
      expect(find.text('最新'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('tab-1')));
      expect(find.text('探索分类'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('tab-2')));
      expect(find.text('历史记录'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('tab-3')));
      await accountTap(tester, 'profile-language');
      await accountTap(tester, 'language-en');
      await back(tester);
      await accountTap(tester, 'profile-sign-out');
      store.signIn('another@example.com', name: 'New Account', register: true);
      expect(store.plus, isFalse);
      expect(store.user?.balance, 100);
      expect(store.user?.orders, isEmpty);
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets('account forms and checkout fit a narrow phone and keyboard', (
    tester,
  ) async {
    await mount(tester, size: const Size(360, 640));
    await tap(tester, find.byKey(const ValueKey('tab-3')));
    await accountTap(tester, 'profile-sign-in');
    tester.view.viewInsets = const FakeViewPadding(bottom: 230);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await accountEnter(tester, 'auth-email', 'small@example.com');
    await accountEnter(tester, 'auth-password', 'demoPass123');
    await accountTap(tester, 'auth-submit');
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await accountTap(tester, 'profile-top-up');
    await accountTap(tester, 'store-continue');
    expect(
      tester.getRect(find.byKey(const ValueKey('checkout-pay'))).bottom,
      lessThanOrEqualTo(640),
    );
    await shot(tester, '33-checkout-small');
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('narrow phone and desktop layouts have no overflow', (
    tester,
  ) async {
    await mount(tester, size: const Size(360, 740));
    await shot(tester, '10-small-phone');
    for (var i = 1; i < 4; i++) {
      await tap(tester, find.byKey(ValueKey('tab-$i')));
      expect(tester.takeException(), isNull);
    }
    tester.view.physicalSize = const Size(1280, 960);
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('tab-0')));
    await shot(tester, '11-desktop');
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}
