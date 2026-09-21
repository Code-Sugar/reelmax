import 'package:flutter/material.dart';
import 'design.dart';
import 'data.dart';
import 'localization.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({
    super.key,
    required this.openDetail,
    this.sections = const {},
  });
  final ValueChanged<DramaInfo> openDetail;
  final Map<String, List<DramaInfo>> sections;
  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  String genre = 'Fantasy';
  final cinema = ScrollController();
  @override
  void dispose() {
    cinema.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth - 40;
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff101412), Color(0xff1a2520), Color(0xff292929)],
            stops: [0, .45, 1],
          ),
        ),
        child: CustomScrollView(
          key: const ValueKey('category-scroll'),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: StickyHeader(
                height: pageTop(context) + 49,
                child: Padding(
                  padding: EdgeInsets.only(top: pageTop(context)),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      'Reel Max',
                      style: type(24, weight: 800, slant: -8, spacing: -1.08),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                constraints: const BoxConstraints(minHeight: 1821),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x003c3423),
                      Color(0x002b3d34),
                      Color(0xff292929),
                      Color(0xff292929),
                    ],
                    stops: [0, .25, .4, 1],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 9, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heading('History', null),
                      const SizedBox(height: 7),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(
                              child: _smallPoster(
                                [
                                  'history-fight-club.png',
                                  'history-fashion.png',
                                  'history-crowd.png',
                                ][i],
                                history: true,
                                progress: [.39, .41, .38][i],
                                alignment: i == 1
                                    ? const Alignment(0, -.3)
                                    : i == 2
                                    ? const Alignment(.06, 0)
                                    : Alignment.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 82,
                        padding: const EdgeInsets.fromLTRB(15, 15, 0, 13),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0x1cffffff)),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0x0effffff),
                              Color(0x050fffff),
                              Color(0x380e1413),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(context, 'Explore Genres'),
                              style: type(
                                13,
                                weight: 650,
                                color: const Color(0x99ebebed),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 27,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(right: 15),
                                itemCount: 5,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  final name = [
                                    'All',
                                    'Fantasy',
                                    'Action',
                                    'Romance',
                                    'Sci-Fi',
                                  ][i];
                                  return Pressable(
                                    label: name,
                                    selected: genre == name,
                                    onTap: () {
                                      setState(() => genre = name);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 360,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 13,
                                      ),
                                      decoration: BoxDecoration(
                                        color: genre == name
                                            ? Colors.white
                                            : const Color(0x17ffffff),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Center(
                                        child: Text(
                                          tr(context, name),
                                          style: type(
                                            12,
                                            weight: 500,
                                            color: genre == name
                                                ? const Color(0xff1f2021)
                                                : const Color(0xfff3f3f4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 39),
                      SizedBox(
                        height: width * (150 / 335 + .203),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: width * 150 / 335,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: ColoredBox(
                                  color: const Color(0xff020302),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 1,
                                        right: -42,
                                        child: Text(
                                          'Reel',
                                          style: type(
                                            108,
                                            weight: 900,
                                            slant: -10,
                                            spacing: -14.04,
                                            height: .9,
                                            color: const Color(0xc71b2809),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 15,
                              left: 15,
                              child: Text(
                                "Don't You Know What To Watch\nTonight?",
                                style: type(
                                  14,
                                  weight: 540,
                                  height: 1.16,
                                  spacing: -.35,
                                ),
                              ),
                            ),
                            Positioned(
                              left: width * .0716,
                              right: width * .0687,
                              bottom: width * .203 - width * 150 / 335 * .3467,
                              child: Row(
                                children: [
                                  for (var i = 0; i < 3; i++) ...[
                                    if (i > 0) SizedBox(width: width * .0269),
                                    Expanded(
                                      child: _poster(
                                        [
                                          'poster-love-scout.png',
                                          'poster-one-of-them-days.png',
                                          'poster-steve.png',
                                        ][i],
                                        [
                                          'Love Scout',
                                          'One of Them Days',
                                          'Steve',
                                        ][i],
                                        ratio: 89 / 132,
                                        scale: 1.06,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Pressable(
                        onTap: null,
                        child: Glass(
                          height: 42,
                          radius: 9,
                          borderOpacity: .38,
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "See More Content You're Interested In",
                                style: type(12, weight: 440),
                              ),
                              const Icon(Icons.chevron_right, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 29),
                      _heading('Hot New', null),
                      const SizedBox(height: 9),
                      SizedBox(
                        height: width * 246 / 335,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 124,
                              child: _poster(
                                'poster-obsession.png',
                                'Obsession',
                                scale: 1.22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 100,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _poster(
                                      'poster-then-you-run.png',
                                      'Then You Run',
                                      scale: 1.48,
                                    ),
                                  ),
                                  const SizedBox(height: 11),
                                  Expanded(
                                    child: _poster(
                                      'poster-horror.png',
                                      'The Best Horror Movie',
                                      scale: 1.18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 29),
                      _heading('Popular Tpday', null),
                      const SizedBox(height: 11),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final file in [
                            'poster-film-yourself.png',
                            'poster-agent-husband.png',
                            'poster-john-wick.png',
                          ]) ...[
                            if (file != 'poster-film-yourself.png')
                              const SizedBox(width: 12),
                            Expanded(child: _smallPoster(file)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 28),
                      _heading('Today In Cinemas', () {
                        final max = cinema.position.maxScrollExtent;
                        cinema.animateTo(
                          cinema.offset >= max - 8
                              ? 0
                              : (cinema.offset + (width + 20) * .69014 + 15)
                                    .clamp(0, max),
                          duration: motion,
                          curve: arrive,
                        );
                      }),
                      const SizedBox(height: 11),
                      SizedBox(
                        height: (width + 20) * .69014 * 331 / 245,
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          maxWidth: width + 20,
                          child: ListView.separated(
                            key: const ValueKey('cinema-scroll'),
                            controller: cinema,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(right: 20),
                            itemCount: 4,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 15),
                            itemBuilder: (_, i) => SizedBox(
                              width: (width + 20) * .69014,
                              child: _poster(
                                [
                                  'poster-chosen-one.png',
                                  'poster-greendale.png',
                                  'euphoria-cover.png',
                                  'fight-club-cover.jpg',
                                ][i],
                                [
                                  'The Chosen One',
                                  'Greendale',
                                  'Euphoria',
                                  'Fight Club',
                                ][i],
                                scale: 1.02,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _heading('Today In Cinemas', null),
                      const SizedBox(height: 12),
                      Pressable(
                        label: 'Unlimited Drama',
                        onTap: () => widget.openDetail(
                          const DramaInfo(
                            title: 'Unlimited Drama',
                            image: 'unlimited-drama-art.png',
                          ),
                        ),
                        child: AspectRatio(
                          aspectRatio: 335 / 128,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                const Art(
                                  'unlimited-drama-art.png',
                                  scale: 1.008,
                                ),
                                Positioned(
                                  top: 23,
                                  left: 15,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'UNLIMITED',
                                        style: type(
                                          22,
                                          weight: 800,
                                          spacing: -.88,
                                          height: .87,
                                          color: const Color(0xffb9b9bb),
                                        ),
                                      ),
                                      Text(
                                        'DRAMA',
                                        style: type(
                                          22,
                                          weight: 800,
                                          spacing: -.88,
                                          height: .87,
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      Container(
                                        width: 124,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xfff3f4f5),
                                              Color(0xffcfd3d5),
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Play',
                                            style: type(
                                              11.5,
                                              weight: 650,
                                              color: canvasColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 108),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _heading(String text, VoidCallback? onTap) => SizedBox(
    height: 37,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          tr(context, text),
          style: type(20, weight: 730, spacing: -.5, height: 1.1),
        ),
        CircleControl(
          label: '查看全部 $text',
          onTap: onTap,
          size: 37,
          child: const Icon(Icons.chevron_right, size: 19),
        ),
      ],
    ),
  );
  Widget _poster(
    String asset,
    String title, {
    double? ratio,
    double scale = 1.035,
  }) {
    final slot = switch (asset) {
      'poster-love-scout.png' => ('recommendations', 0),
      'poster-one-of-them-days.png' => ('recommendations', 1),
      'poster-steve.png' => ('recommendations', 2),
      'poster-obsession.png' => ('hot new', 0),
      'poster-then-you-run.png' => ('hot new', 1),
      'poster-horror.png' => ('hot new', 2),
      'poster-chosen-one.png' => ('today in cinemas', 0),
      'poster-greendale.png' => ('today in cinemas', 1),
      'euphoria-cover.png' => ('today in cinemas', 2),
      'fight-club-cover.jpg' => ('today in cinemas', 3),
      _ => ('', 0),
    };
    final rows = widget.sections[slot.$1] ?? const <DramaInfo>[];
    final remote = rows.length > slot.$2 ? rows[slot.$2] : null;
    final child = Pressable(
      label: remote?.title ?? title,
      onTap: () => widget.openDetail(
        remote ?? DramaInfo(title: title, image: asset, posterScale: scale),
      ),
      child: SizedBox.expand(
        child: Art(
          remote?.image.isNotEmpty == true ? remote!.image : asset,
          scale: remote == null ? scale : 1,
          radius: 10,
        ),
      ),
    );
    return ratio == null
        ? child
        : AspectRatio(aspectRatio: ratio, child: child);
  }

  Widget _smallPoster(
    String asset, {
    bool history = false,
    double progress = .4,
    Alignment alignment = Alignment.center,
  }) => Pressable(
    key: ValueKey('category-$asset'),
    label: '打开 My Sister Covets',
    onTap: () => widget.openDetail(
      DramaInfo(title: 'My Sister Covets', image: asset, genre: 'Romance'),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 104 / (history ? 151 : 152),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Art(asset, alignment: alignment, scale: 1.035),
                if (history)
                  Center(
                    child: Glass(
                      width: 33,
                      height: 33,
                      borderOpacity: .34,
                      child: const Center(
                        child: Icon(Icons.play_arrow_rounded, size: 18),
                      ),
                    ),
                  ),
                if (history)
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 1080),
                        curve: arrive,
                        builder: (_, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 4,
                          color: Colors.white,
                          backgroundColor: const Color(0x5c1f2424),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'My Sister Covets',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: type(12, weight: 520, height: 1.05, spacing: -.18),
        ),
        const SizedBox(height: 2),
        Text('Romance', style: type(10, color: const Color(0x87e6e6e8))),
      ],
    ),
  );
}
