import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'category.dart';
import 'design.dart';
import 'data.dart';
import 'detail.dart';
import 'home.dart';
import 'library.dart';
import 'search.dart';
import 'profile.dart';
import 'account_state.dart';
import 'localization.dart';
import 'startup.dart';
import 'api.dart';
import 'live_catalog.dart';

bool get _showPrototypeStatusBar =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

class ReelMaxApp extends StatefulWidget {
  const ReelMaxApp({super.key, this.demo = false});
  final bool demo;
  @override
  State<ReelMaxApp> createState() => _ReelMaxAppState();
}

class _ReelMaxAppState extends State<ReelMaxApp> {
  late final account = AccountStore(api: widget.demo ? null : SkitApi());
  @override
  void initState() {
    super.initState();
    account.initialize();
  }

  @override
  void dispose() {
    account.dispose();
    account.api?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AccountScope(
    store: account,
    child: MaterialApp(
      title: 'Reel Max',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Commissioner',
        scaffoldBackgroundColor: canvasColor,
        colorScheme: const ColorScheme.dark(primary: Colors.white),
        splashFactory: NoSplash.splashFactory,
        useMaterial3: true,
      ),
      home: const _PhoneStage(),
    ),
  );
}

class _PhoneStage extends StatelessWidget {
  const _PhoneStage();
  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    body: LayoutBuilder(
      builder: (context, constraints) {
        // Android can attach the Flutter surface before sending its first size.
        if (constraints.biggest.isEmpty) {
          return const ColoredBox(color: canvasColor);
        }
        final desktop = constraints.maxWidth > 520;
        final devicePadding = desktop
            ? EdgeInsets.zero
            : MediaQuery.paddingOf(context);
        final pagePadding = devicePadding.copyWith(
          top: _showPrototypeStatusBar
              ? math.max(36, devicePadding.top)
              : devicePadding.top,
        );
        final width = desktop
            ? math.min(430.0, constraints.maxWidth - 36)
            : constraints.maxWidth;
        final height = desktop
            ? math.max(660.0, math.min(900.0, constraints.maxHeight - 36))
            : constraints.maxHeight;
        return Container(
          decoration: BoxDecoration(
            gradient: desktop
                ? const RadialGradient(
                    center: Alignment(0, -.84),
                    radius: 1.1,
                    colors: [
                      Color(0xff39393d),
                      Color(0xff1b1b1e),
                      Color(0xff101012),
                    ],
                    stops: [0, .34, 1],
                  )
                : null,
            color: desktop ? null : canvasColor,
          ),
          child: Center(
            child: Container(
              width: width,
              height: height,
              decoration: desktop
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(44),
                      border: Border.all(color: const Color(0x1cffffff)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x80000000),
                          blurRadius: 90,
                          offset: Offset(0, 36),
                        ),
                      ],
                    )
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(desktop ? 44 : 0),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: Size(width, height),
                    textScaler: TextScaler.noScaling,
                    padding: pagePadding,
                  ),
                  child: const StartupGate(child: _AppShell()),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _AppShell extends StatefulWidget {
  const _AppShell();
  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  final navigator = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) navigator.currentState?.maybePop();
    },
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            navigator.currentState?.maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Navigator(
              key: navigator,
              onGenerateRoute: (_) => PageRouteBuilder<void>(
                pageBuilder: (_, animation, secondary) => AnimatedBuilder(
                  animation: secondary,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, secondary.value * 8),
                    child: Transform.scale(
                      scale: 1 - secondary.value * .028,
                      child: child,
                    ),
                  ),
                  child: const _Tabs(),
                ),
                transitionsBuilder: (_, animation, secondary, child) => child,
              ),
            ),
            if (_showPrototypeStatusBar)
              const Positioned(top: 0, left: 0, right: 0, child: _StatusBar()),
          ],
        ),
      ),
    ),
  );
}

class _Tabs extends StatefulWidget {
  const _Tabs();
  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  int tab = 0;
  final visited = <int>{0};
  bool detailOpen = false;
  int routeCount = 0;
  final likedDramas = <String>{};
  Future<void> openPage(Widget page) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => routeCount++);
    try {
      await Navigator.of(context).push(reelRoute(page));
    } finally {
      if (mounted) setState(() => routeCount--);
    }
  }

  void openSearch() => openPage(
    AccountScope.of(context).live
        ? LiveListPage(
            title: 'Search',
            path: 'skit/search',
            search: true,
            openDetail: openDetail,
          )
        : SearchPage(openDetail: openDetail, showBack: true),
  );
  Future<void> openDetail(DramaInfo drama) async {
    if (detailOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => detailOpen = true);
    await openPage(
      drama.serverId != null
          ? LiveDetail(drama: drama)
          : DetailPage(
              drama: drama,
              initialLiked: likedDramas.contains(drama.id),
              onLiked: (value) => value
                  ? likedDramas.add(drama.id)
                  : likedDramas.remove(drama.id),
            ),
    );
    if (mounted) setState(() => detailOpen = false);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: canvasColor,
    child: Stack(
      fit: StackFit.expand,
      children: [
        IndexedStack(
          index: tab,
          children: [
            for (var index = 0; index < 4; index++)
              TickerMode(
                enabled: tab == index,
                child: !visited.contains(index)
                    ? const SizedBox.shrink()
                    : switch (index) {
                        0 =>
                          AccountScope.of(context).live
                              ? LiveHome(
                                  active: tab == 0 && routeCount == 0,
                                  openDetail: openDetail,
                                  openSearch: openSearch,
                                )
                              : HomePage(
                                  openDetail: openDetail,
                                  active: tab == 0 && routeCount == 0,
                                  openSearch: openSearch,
                                ),
                        1 =>
                          AccountScope.of(context).live
                              ? LiveCategory(openDetail: openDetail)
                              : CategoryPage(openDetail: openDetail),
                        2 =>
                          AccountScope.of(context).live
                              ? LiveListPage(
                                  title: 'List',
                                  path: 'skit/myCollectList',
                                  library: true,
                                  openDetail: openDetail,
                                )
                              : LibraryPage(openDetail: openDetail),
                        _ => ProfilePage(
                          openPage: openPage,
                          openSearch: openSearch,
                        ),
                      },
              ),
          ],
        ),
        Positioned(
          left: MediaQuery.sizeOf(context).width * .1,
          right: MediaQuery.sizeOf(context).width * .1,
          bottom: math.max(18, MediaQuery.paddingOf(context).bottom),
          child: IgnorePointer(
            ignoring: routeCount > 0,
            child: AnimatedOpacity(
              opacity: routeCount > 0 ? 0 : 1,
              duration: pageExitMotion,
              child: _TabBar(
                selected: tab,
                onChange: (value) {
                  if (tab != value) {
                    setState(() {
                      tab = value;
                      visited.add(value);
                    });
                  }
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onChange});
  final int selected;
  final ValueChanged<int> onChange;
  @override
  Widget build(BuildContext context) => Glass(
    variant: GlassVariant.navigation,
    height: 62,
    radius: 32,
    blur: 12,
    borderOpacity: .38,
    child: LayoutBuilder(
      builder: (_, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 4;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: motion,
              curve: spring,
              top: 5,
              bottom: 5,
              left: 5 + itemWidth * selected,
              width: itemWidth,
              child: const Glass(
                variant: GlassVariant.selection,
                radius: 27,
                borderOpacity: .42,
                child: SizedBox.expand(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Pressable(
                        key: ValueKey('tab-$i'),
                        label: tr(
                          context,
                          ['Today', '分类', 'List', 'Profile'][i],
                        ),
                        selected: i == selected,
                        onTap: () => onChange(i),
                        child: Center(
                          child: AnimatedScale(
                            scale: selected == i ? 1.08 : 1,
                            duration: motion,
                            curve: spring,
                            child: Glyph(
                              '${['play', 'category', 'bookmark', 'profile'][i]}-${selected == i ? 'active' : 'inactive'}',
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 18, 28, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('9:41', style: type(17, weight: 650, spacing: -.35)),
            const SizedBox(
              width: 82,
              height: 15,
              child: CustomPaint(painter: _StatusPainter()),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatusPainter extends CustomPainter {
  const _StatusPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1 + i * 5, 10.0 - i * 3, 3, 4.0 + i * 3),
          const Radius.circular(1),
        ),
        paint,
      );
    }
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = 5.2 + i * 3.2;
      final half = 8.5 - i * 3.1;
      canvas.drawPath(
        Path()
          ..moveTo(37 - half, y)
          ..quadraticBezierTo(37, y - 5 + i, 37 + half, y),
        paint,
      );
    }
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(37, 13.4), 1.1, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(55, 1, 23, 12),
        const Radius.circular(3),
      ),
      paint,
    );
    canvas.drawLine(const Offset(80, 5), const Offset(80, 9), paint);
    paint.style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(57, 3, 19, 8),
        const Radius.circular(1.6),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StatusPainter oldDelegate) => false;
}
