import 'dart:ui';
import 'package:flutter/material.dart';
import 'data.dart';
import 'design.dart';
import 'player.dart';
import 'localization.dart';
import 'api.dart';

Route<void> reelRoute(Widget child, {bool player = false}) =>
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: .2),
      transitionDuration: pageEnterMotion,
      reverseTransitionDuration: pageExitMotion,
      pageBuilder: (_, animation, secondary) => child,
      transitionsBuilder: (_, animation, secondary, child) {
        final t = CurvedAnimation(
          parent: animation,
          curve: arrive,
          reverseCurve: arrive,
        );
        return AnimatedBuilder(
          animation: t,
          child: child,
          builder: (_, child) => Opacity(
            opacity: t.value.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, (player ? 28 : 16) * (1 - t.value)),
              child: Transform.scale(
                scale: (player ? .94 : .95) + (player ? .06 : .05) * t.value,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38 * (1 - t.value)),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );

class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.drama,
    required this.initialLiked,
    required this.onLiked,
    this.toggleLike,
    this.playEpisode,
    this.remoteEpisodes,
    this.likeCount,
    this.score,
  });
  final Future<bool> Function(bool value)? toggleLike;
  final Future<void> Function(int index)? playEpisode;
  final List<Json>? remoteEpisodes;
  final int? likeCount;
  final String? score;
  final DramaInfo drama;
  final bool initialLiked;
  final ValueChanged<bool> onLiked;
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late bool liked = widget.initialLiked;
  bool expanded = false;
  bool liking = false;
  String? error;
  int likeDelta = 0;
  @override
  void didUpdateWidget(covariant DetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLiked != widget.initialLiked ||
        oldWidget.likeCount != widget.likeCount) {
      liked = widget.initialLiked;
      likeDelta = 0;
    }
  }

  Future<void> toggleLike() async {
    if (liking) return;
    final next = !liked;
    setState(() {
      liking = true;
      error = null;
    });
    try {
      final accepted = await widget.toggleLike?.call(next) ?? true;
      if (!mounted || !accepted) return;
      setState(() {
        liked = next;
        likeDelta += next ? 1 : -1;
      });
      widget.onLiked(next);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => liking = false);
    }
  }

  String get synopsis => widget.drama.description.isEmpty
      ? detailSynopsis
      : widget.drama.description;

  void openPlayer([int index = 0]) {
    if (widget.playEpisode != null) {
      widget.playEpisode!(index);
      return;
    }
    Navigator.of(context).push(
      reelRoute(
        PlayerPage(
          initialEpisode: index,
          sources: [widget.drama.preview, ...episodes.skip(1)],
        ),
        player: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('detail-page'),
    color: const Color(0xff111111),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 38, sigmaY: 38),
            child: Transform.scale(
              scale: 1.3,
              child: Art(widget.drama.image, alignment: Alignment.topCenter),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xaa080c0b),
                  Color(0x990d1210),
                  Color(0xf5111111),
                  Color(0xff111111),
                ],
                stops: [0, .35, .83, 1],
              ),
            ),
          ),
        ),
        // Scrolling belongs to the content; it never moves or dismisses a route.
        CustomScrollView(
          key: const ValueKey('detail-scroll'),
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: StickyHeader(
                height: pageTop(context) + 89,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, pageTop(context), 24, 0),
                  child: Column(
                    children: [
                      Text(
                        'Reel Max',
                        style: type(29, weight: 800, spacing: -1.305),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleControl(
                            label: '返回上一页',
                            onTap: () => Navigator.of(context).pop(),
                            child: const Glyph('detail-back', size: 25),
                          ),
                          Row(
                            children: [
                              LikeFeedback(
                                active: liked,
                                child: Pressable(
                                  label: liked ? '取消喜欢' : '喜欢',
                                  selected: liked,
                                  onTap: liking ? null : toggleLike,
                                  child: Glass(
                                    height: 36,
                                    red: liked,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Glyph(
                                          liked
                                              ? 'player-heart-filled'
                                              : 'detail-heart',
                                          size: 14,
                                          color: liked
                                              ? const Color(0xffff4167)
                                              : null,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          widget.likeCount == null
                                              ? (liked ? '1365' : '1364')
                                              : '${widget.likeCount! + likeDelta}',
                                          style: type(
                                            14,
                                            color: liked
                                                ? const Color(0xffff4167)
                                                : const Color(0xffe0e2e2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Pressable(
                                label: '查看评分',
                                onTap: null,
                                child: Glass(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      const Glyph('detail-star', size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${widget.score ?? '7.9'}/10',
                                        style: type(
                                          14,
                                          color: const Color(0xffe0e2e2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                38 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList.list(
                children: [
                  AspectRatio(
                    aspectRatio: 434 / 431,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Art(
                            widget.drama.image,
                            key: const ValueKey('detail-poster'),
                            scale: widget.drama.posterScale,
                          ),
                          Positioned(
                            bottom: 15,
                            right: 14,
                            child: Pressable(
                              label: 'Watch Trailer',
                              onTap: openPlayer,
                              child: Glass(
                                height: 45,
                                dark: true,
                                borderOpacity: .08,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    const Glyph('detail-play'),
                                    const SizedBox(width: 8),
                                    Text(
                                      tr(context, 'Watch Trailer'),
                                      style: type(14, weight: 560),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.drama.title,
                    key: const ValueKey('detail-title'),
                    style: type(28, weight: 800, spacing: -1.26),
                  ),
                  if (widget.drama.genre.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      widget.drama.genre,
                      style: type(12, color: const Color(0xffc5c5ca)),
                    ),
                  ],
                  const SizedBox(height: 9),
                  Text(
                    synopsis,
                    key: const ValueKey('detail-synopsis'),
                    maxLines: expanded ? null : 4,
                    overflow: expanded ? null : TextOverflow.ellipsis,
                    style: type(
                      14,
                      height: 1.55,
                      color: const Color(0xffaaa9ad),
                    ),
                  ),
                  if (synopsis.length > 160) ...[
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Pressable(
                        onTap: () => setState(() => expanded = !expanded),
                        child: Text(
                          tr(context, expanded ? 'Less' : 'More'),
                          style: type(14, weight: 650, height: 1.5),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  Text(
                    tr(context, 'Cast'),
                    style: type(21, weight: 750, spacing: -.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    key: const ValueKey('detail-cast'),
                    height: 122,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: detailCast.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (_, index) {
                        final actor = detailCast[index];
                        return SizedBox(
                          width: 82,
                          child: Column(
                            children: [
                              Art(
                                actor.image,
                                width: 82,
                                height: 82,
                                radius: 41,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                actor.name,
                                textAlign: TextAlign.center,
                                style: type(12, weight: 500, height: 1.3),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr(context, 'Episodes'),
                        style: type(21, weight: 750, spacing: -.4),
                      ),
                      Text(
                        widget.remoteEpisodes == null
                            ? tr(context, '3 available')
                            : '${widget.remoteEpisodes!.length} ${tr(context, 'Episodes')}',
                        style: type(12, color: const Color(0xffaaa9ad)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        error!,
                        style: type(12, color: const Color(0xffff4167)),
                      ),
                    ),
                  if (widget.remoteEpisodes != null)
                    LayoutBuilder(
                      builder: (context, constraints) => SizedBox(
                        key: const ValueKey('detail-episodes'),
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.remoteEpisodes!.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final episode = widget.remoteEpisodes![i];
                            final locked =
                                integer(episode['needPay']) == 1 &&
                                integer(episode['isUnlocked']) != 1;
                            return SizedBox(
                              width: (constraints.maxWidth - 20) / 3,
                              child: Pressable(
                                key: ValueKey('detail-episode-$i'),
                                onTap: () => openPlayer(i),
                                child: Glass(
                                  height: 52,
                                  radius: 16,
                                  borderOpacity: .18,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (locked)
                                        const Icon(Icons.lock_outline, size: 16)
                                      else
                                        const Glyph('detail-play', size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${i + 1}'.padLeft(2, '0'),
                                        style: type(16, weight: 650),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (widget.remoteEpisodes == null)
                    Row(
                      key: const ValueKey('detail-episodes'),
                      children: [
                        for (var i = 0; i < episodes.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: Pressable(
                              key: ValueKey('detail-episode-$i'),
                              label: '播放第 ${i + 3} 集',
                              onTap: () => openPlayer(i),
                              child: Glass(
                                height: 52,
                                radius: 16,
                                borderOpacity: .18,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Glyph('detail-play', size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      '0${i + 3}',
                                      style: type(16, weight: 650),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 28),
                  Text(
                    tr(context, 'You Might Like'),
                    style: type(21, weight: 750, spacing: -.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    key: const ValueKey('detail-recommendations'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final drama in [
                        searchDramas[0],
                        searchDramas[2],
                      ]) ...[
                        if (drama != searchDramas[0]) const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: .72,
                                child: Art(drama.image, radius: 16),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                drama.title,
                                style: type(14, weight: 650, height: 1.25),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Drama · Romance',
                                style: type(11, color: const Color(0xffaaa9ad)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
