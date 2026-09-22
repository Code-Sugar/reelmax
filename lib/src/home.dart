import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'data.dart';
import 'data.dart' as catalog;
import 'design.dart';
import 'media.dart';
import 'home_video_pool.dart';
import 'vertical_swipe.dart';
import 'localization.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.openDetail,
    required this.active,
    required this.openSearch,
    this.items,
    this.selectedFilter,
    this.onFilter,
    this.filters = const ['New', 'Top', 'Exclusive'],
  });
  final ValueChanged<DramaInfo> openDetail;
  final bool active;
  final VoidCallback openSearch;
  final List<Feature>? items;
  final String? selectedFilter;
  final ValueChanged<String>? onFilter;
  final List<String> filters;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Feature> get features => widget.items ?? catalog.features;
  late final videos = HomeVideoPool()..addListener(refreshSwipe);
  String filter = 'New';
  int feature = 0;
  bool collapsed = false, expanding = false;
  double dockDrag = 0;
  late final swipe = VerticalSwipeController(
    vsync: this,
    duration: const Duration(milliseconds: 580),
    curve: Curves.easeInOutCubic,
    onChanged: (step) => setState(() {
      feature = (feature + step) % features.length;
    }),
  )..addListener(refreshSwipe);

  void refreshSwipe() => setState(() {});
  late final AnimationController transition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  @override
  void dispose() {
    videos.dispose();
    swipe.dispose();
    transition.dispose();
    super.dispose();
  }

  double get bottom => math.max(18, MediaQuery.paddingOf(context).bottom) + 88;
  Future<void> showNext() async {
    if (expanding || swipe.active || features.length < 2) return;
    setState(() => expanding = true);
    try {
      await transition.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    setState(() {
      feature = (feature + 1) % features.length;
      expanding = false;
    });
    transition.reset();
  }

  void collapse(bool value) {
    setState(() {
      collapsed = value;
      dockDrag = 0;
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth, height = constraints.maxHeight;
      final nextWidth = (width * .2).clamp(72.0, 82.0);
      if (features.isEmpty) return const SizedBox.expand();
      feature = feature.clamp(0, features.length - 1);
      final next = features[(feature + 1) % features.length];
      final incoming = (feature + swipe.direction) % features.length;
      videos.configure(
        widget.active
            ? [
                features[feature].video,
                next.video,
                features[(feature - 1) % features.length].video,
              ]
            : [],
        widget.active
            ? {
                if (!expanding) features[feature].video,
                if (expanding || (!collapsed && !swipe.active)) next.video,
                if (swipe.active) features[incoming].video,
              }
            : {},
      );
      return GestureDetector(
        key: const ValueKey('home-swipe'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: collapsed && !expanding && features.length > 1
            ? (_) => swipe.start()
            : null,
        onVerticalDragUpdate: collapsed && !expanding && features.length > 1
            ? (details) => swipe.update(details, height)
            : null,
        onVerticalDragEnd: collapsed && !expanding && features.length > 1
            ? (details) => swipe.end(details, height)
            : null,
        onVerticalDragCancel: collapsed ? swipe.cancel : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final i in {feature, if (swipe.active) incoming})
              Offstage(
                key: ValueKey('home-frame-$i-${features[i].video}'),
                offstage:
                    i != feature &&
                    !(swipe.active &&
                        i == (feature + swipe.direction) % features.length),
                child: Transform.translate(
                  key: ValueKey('home-video-$i'),
                  offset: Offset(
                    0,
                    swipe.offset +
                        (i == feature ? 0 : swipe.direction * height),
                  ),
                  child: IgnorePointer(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PreviewVideo(
                          source: features[i].video,
                          poster: features[i].image,
                          controller: videos.controllerFor(features[i].video),
                        ),
                        const _HeroShade(),
                        AnimatedPositioned(
                          duration: motion,
                          curve: arrive,
                          left: 20,
                          // Leave space for both the preview and its 32px
                          // toggle, including the gap between copy and toggle.
                          right: math.max(
                            20,
                            (collapsed ? 70 : nextWidth + 74) - dockDrag,
                          ),
                          bottom: bottom,
                          child: _HeroCopy(feature: features[i], width: width),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Pressable(
              key: const ValueKey('hero-open'),
              label: '打开 ${features[feature].title} 详情',
              onTap: () {
                if (!swipe.active && !expanding) {
                  widget.openDetail(features[feature].detail);
                }
              },
              child: const SizedBox.expand(),
            ),
            AnimatedPositioned(
              duration: motion,
              curve: arrive,
              right: collapsed ? 16 - nextWidth - dockDrag : 20 - dockDrag,
              bottom: bottom,
              width: nextWidth + 42,
              height: nextWidth / .58,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    left: 42,
                    child: Pressable(
                      key: const ValueKey('next-teaser'),
                      label: collapsed ? '展开下一部作品卡片' : '展示下一部作品：${next.title}',
                      onTap: () => collapsed ? collapse(false) : showNext(),
                      onHorizontalDragUpdate: (d) => setState(
                        () => dockDrag = (dockDrag + d.delta.dx).clamp(
                          collapsed ? -nextWidth - 4 : 0,
                          collapsed ? 0 : nextWidth + 4,
                        ),
                      ),
                      onHorizontalDragEnd: (_) =>
                          collapse(collapsed ? dockDrag > -18 : dockDrag > 18),
                      child: AnimatedOpacity(
                        opacity: collapsed ? .32 : 1,
                        duration: pageExitMotion,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              PreviewVideo(
                                key: ValueKey(next.video),
                                source: next.video,
                                poster: next.image,
                                controller: videos.controllerFor(next.video),
                              ),
                              Positioned(
                                left: 5,
                                right: 5,
                                bottom: 5,
                                child: Glass(
                                  height: 22,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Glyph('next', size: 12),
                                      const SizedBox(width: 3),
                                      Text(
                                        tr(context, 'Next'),
                                        style: type(9, weight: 500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (collapsed)
                                Positioned(
                                  left: 3,
                                  top: nextWidth / .58 / 2 - 14.5,
                                  child: Container(
                                    width: 4,
                                    height: 29,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(99),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.white60,
                                          blurRadius: 9,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: nextWidth / .58 / 2 - 16,
                    child: CircleControl(
                      key: ValueKey(
                        collapsed ? 'next-expand' : 'next-collapse',
                      ),
                      onTap: () => collapse(!collapsed),
                      size: 32,
                      label: collapsed ? '从右侧展开 Next 卡片' : '将 Next 卡片收进右侧',
                      child: Icon(
                        collapsed ? Icons.chevron_left : Icons.chevron_right,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (expanding)
              AnimatedBuilder(
                animation: transition,
                builder: (_, _) {
                  final t = Curves.easeInOutCubic.transform(transition.value);
                  final origin = Rect.fromLTWH(
                    width - 20 - nextWidth,
                    height - bottom - nextWidth / .58,
                    nextWidth,
                    nextWidth / .58,
                  );
                  final rect = Rect.lerp(
                    origin,
                    Offset.zero & constraints.biggest,
                    t,
                  )!;
                  return Positioned.fromRect(
                    rect: rect,
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          expanding ? 13 * (1 - t) : 0,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            PreviewVideo(
                              source: next.video,
                              poster: next.image,
                              controller: videos.controllerFor(next.video),
                            ),
                            const _HeroShade(),
                            if (t > .65)
                              Positioned(
                                left: 20,
                                right: 18,
                                bottom: bottom,
                                child: Opacity(
                                  opacity: ((t - .65) / .35).clamp(0, 1),
                                  child: _HeroCopy(feature: next, width: width),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            Positioned(
              top: pageTop(context),
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    'Reel Max',
                    style: type(29, weight: 800, spacing: -1.305),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: width < 370 ? 16 : 20,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final name in widget.filters) ...[
                                  SizedBox(
                                    width: width <= 370
                                        ? (name == 'Exclusive' ? 100 : 62)
                                        : name == 'Exclusive'
                                        ? (width * .3196).clamp(100, 124)
                                        : (width *
                                                  (name == 'Top'
                                                      ? .201
                                                      : .1985))
                                              .clamp(
                                                64,
                                                name == 'Top' ? 78 : 77,
                                              ),
                                    child: Pressable(
                                      label: name,
                                      selected:
                                          (widget.selectedFilter ?? filter) ==
                                          name,
                                      onTap: () {
                                        setState(() => filter = name);
                                        widget.onFilter?.call(name);
                                      },
                                      child: Glass(
                                        variant: GlassVariant.filter,
                                        height: width <= 370 ? 35 : 37,
                                        active:
                                            (widget.selectedFilter ?? filter) ==
                                            name,
                                        child: Center(
                                          child: Text(
                                            tr(context, name),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: type(
                                              14,
                                              weight: 650,
                                              color:
                                                  (widget.selectedFilter ??
                                                          filter) ==
                                                      name
                                                  ? const Color(0xff242426)
                                                  : ink,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (name != widget.filters.last)
                                    SizedBox(width: width <= 370 ? 6 : 8),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleControl(
                          key: const ValueKey('home-search'),
                          label: '搜索',
                          variant: GlassVariant.filter,
                          size: width <= 370 ? 35 : 37,
                          onTap: widget.openSearch,
                          child: const Glyph('search', size: 26),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _HeroShade extends StatelessWidget {
  const _HeroShade();
  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x2e030508), Color(0x00030406), Color(0xdb030406)],
          stops: [.05, .42, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(.48, -.7),
            radius: .6,
            colors: [Color(0x3854b7c5), Colors.transparent],
          ),
        ),
      ),
    ),
  );
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.feature, required this.width});
  final Feature feature;
  final double width;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xffff453a),
            borderRadius: BorderRadius.circular(5),
          ),
            child: Text(
              // Some catalog entries have no genres yet; keep the tag legible.
              feature.genre.trim().isEmpty ? 'Drama' : feature.genre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type(10, weight: 650, height: 1.2),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        feature.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: type(
          (width * .064).clamp(22, 26),
          weight: 900,
          spacing: -.468,
          flare: 10,
          volume: 48,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        feature.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: type(12, height: 1.35, color: const Color(0xccffffff)),
      ),
      const SizedBox(height: 13),
      Glass(
        variant: GlassVariant.play,
        width: 152,
        height: 48,
        active: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Glyph('play-button'),
            const SizedBox(width: 7),
            Text(
              tr(context, 'Play'),
              style: type(15, weight: 700, color: canvasColor),
            ),
          ],
        ),
      ),
    ],
  );
}
