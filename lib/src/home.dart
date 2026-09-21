import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'data.dart';
import 'data.dart' as catalog;
import 'design.dart';
import 'media.dart';
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
  });
  final ValueChanged<DramaInfo> openDetail;
  final bool active;
  final VoidCallback openSearch;
  final List<Feature>? items;
  final String? selectedFilter;
  final ValueChanged<String>? onFilter;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Feature> get features => widget.items ?? catalog.features;
  String filter = 'New';
  int feature = 0;
  bool collapsed = false, expanding = false;
  double dockDrag = 0;
  late final swipe = VerticalSwipeController(
    vsync: this,
    onChanged: (step) => setState(() {
      feature = (feature + step) % features.length;
    }),
  )..addListener(refreshSwipe);

  void refreshSwipe() => setState(() {});
  late final AnimationController transition = AnimationController(
    vsync: this,
    duration: contentSwitchMotion,
  );
  @override
  void dispose() {
    swipe.dispose();
    transition.dispose();
    super.dispose();
  }

  double get bottom => math.max(18, MediaQuery.paddingOf(context).bottom) + 88;
  Future<void> showNext() async {
    if (expanding || swipe.active) return;
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
      final next = features[(feature + 1) % features.length];
      return GestureDetector(
        key: const ValueKey('home-swipe'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) {
          if (!expanding) swipe.start();
        },
        onVerticalDragUpdate: (details) {
          if (!expanding) swipe.update(details, height);
        },
        onVerticalDragEnd: (details) {
          if (!expanding) swipe.end(details, height);
        },
        onVerticalDragCancel: swipe.cancel,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < features.length; i++)
              Offstage(
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
                          active:
                              widget.active &&
                              !expanding &&
                              (i == feature ||
                                  (swipe.active &&
                                      i ==
                                          (feature + swipe.direction) %
                                              features.length)),
                        ),
                        const _HeroShade(),
                        Positioned(
                          left: 20,
                          right: nextWidth + 40,
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
                                active:
                                    widget.active &&
                                    !collapsed &&
                                    !expanding &&
                                    !swipe.active,
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
                  final t = arrive.transform(transition.value);
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
                              active: widget.active,
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
                        for (final name in ['New', 'Top', 'Exclusive']) ...[
                          SizedBox(
                            width: width <= 370
                                ? (name == 'Exclusive' ? 100 : 62)
                                : name == 'Exclusive'
                                ? (width * .3196).clamp(100, 124)
                                : (width * (name == 'Top' ? .201 : .1985))
                                      .clamp(64, name == 'Top' ? 78 : 77),
                            child: Pressable(
                              label: name,
                              selected:
                                  (widget.selectedFilter ?? filter) == name,
                              onTap: () {
                                setState(() => filter = name);
                                widget.onFilter?.call(name);
                              },
                              child: Glass(
                                variant: GlassVariant.filter,
                                height: width <= 370 ? 35 : 37,
                                active:
                                    (widget.selectedFilter ?? filter) == name,
                                child: Center(
                                  child: Text(
                                    tr(context, name),
                                    style: type(
                                      14,
                                      weight: 650,
                                      color:
                                          (widget.selectedFilter ?? filter) ==
                                              name
                                          ? const Color(0xff242426)
                                          : ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (name != 'Exclusive')
                            SizedBox(width: width <= 370 ? 6 : 8),
                        ],
                        const Spacer(),
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
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xffff453a),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(feature.age, style: type(9, weight: 700)),
          ),
          const SizedBox(width: 9),
          Text(feature.genre, style: type(12, color: const Color(0xc2ffffff))),
        ],
      ),
      const SizedBox(height: 8),
      OverflowBox(
        fit: OverflowBoxFit.deferToChild,
        alignment: Alignment.centerLeft,
        maxWidth: width - 40,
        child: Text(
          feature.title,
          maxLines: 1,
          style: type(
            (width * .064).clamp(22, 26),
            weight: 900,
            spacing: -.468,
            flare: 10,
            volume: 48,
          ),
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
