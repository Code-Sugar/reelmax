import 'dart:ui';
import 'package:flutter/material.dart';
import 'design.dart';
import 'localization.dart';

const playerEpisodeCount = 20;
const unlockedEpisodeCount = 5;
const playerQualities = ['720p', '1080p', '2K', '4K'];
const collectionYellow = Color(0xffffd05a);

/// A shared, scrollable sheet that stays within the player's nested navigator.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title, subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: const Color(0x26ffffff)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xf2272a2d), Color(0xfa111315)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 22),
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x66ffffff),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, title),
                            style: type(25, weight: 750, spacing: -.6),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            tr(context, subtitle),
                            style: type(12, color: const Color(0xffa7aaae)),
                          ),
                        ],
                      ),
                    ),
                    CircleControl(
                      label: '关闭$title',
                      size: 34,
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class EpisodePanel extends StatefulWidget {
  const EpisodePanel({
    super.key,
    required this.current,
    this.available = unlockedEpisodeCount,
    this.locks,
    this.allowLockedSelection = false,
  });
  final int current;
  final int available;
  final List<bool>? locks;
  final bool allowLockedSelection;

  @override
  State<EpisodePanel> createState() => _EpisodePanelState();
}

class _EpisodePanelState extends State<EpisodePanel> {
  int? tappedLocked;
  int get count => widget.locks?.length ?? playerEpisodeCount;
  int get available =>
      widget.locks?.where((locked) => !locked).length ?? widget.available;

  @override
  Widget build(BuildContext context) => PlayerPanel(
    key: const ValueKey('episode-panel'),
    title: 'Episodes',
    subtitle: widget.locks != null
        ? tr(
            context,
            '$count episodes · $available available',
            '共 $count 集 · $available 集可观看',
          )
        : widget.available == 5
        ? '20 episodes · 5 available'
        : tr(context, '20 episodes · All unlocked', '共 20 集 · 已全部解锁'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: count,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 58,
          ),
          itemBuilder: (context, index) {
            final number = index + 1;
            final locked = widget.locks?[index] ?? number > widget.available;
            final selected = number == widget.current;
            final color = selected
                ? const Color(0xff17191b)
                : locked
                ? const Color(0xff777c83)
                : Colors.white;
            return Pressable(
              key: ValueKey('episode-option-$number'),
              label: locked ? '第 $number 集，已锁定' : '播放第 $number 集',
              selected: selected,
              onTap: () {
                if (locked && !widget.allowLockedSelection) {
                  setState(() => tappedLocked = number);
                } else {
                  Navigator.of(context).pop(number);
                }
              },
              child: AnimatedContainer(
                duration: motion,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: selected
                      ? const Color(0xfff1f3f4)
                      : locked
                      ? const Color(0x06ffffff)
                      : const Color(0x15ffffff),
                  border: Border.all(
                    color: selected ? Colors.white : const Color(0x13ffffff),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      number.toString().padLeft(2, '0'),
                      style: type(17, weight: 650, color: color),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 12,
                      child: locked
                          ? Icon(
                              Icons.lock_rounded,
                              key: ValueKey('episode-lock-$number'),
                              size: 11,
                              color: color,
                            )
                          : selected
                          ? Icon(
                              Icons.equalizer_rounded,
                              size: 13,
                              color: color,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                available == count
                    ? Icons.verified_outlined
                    : Icons.lock_outline_rounded,
                size: 13,
                color: Color(0xffa7aaae),
              ),
              const SizedBox(width: 7),
              Text(
                available == count
                    ? tr(context, 'All episodes unlocked', '全部剧集已解锁')
                    : tappedLocked == null
                    ? widget.locks == null
                          ? tr(context, 'Episodes 06–20 are locked')
                          : tr(
                              context,
                              'Locked episodes require unlocking',
                              '上锁剧集需解锁后观看',
                            )
                    : tr(
                        context,
                        'Episode ${tappedLocked!.toString().padLeft(2, '0')} is locked',
                        '第 $tappedLocked 集尚未解锁',
                      ),
                key: const ValueKey('episode-lock-message'),
                style: type(12, color: const Color(0xffa7aaae)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class QualityPanel extends StatelessWidget {
  const QualityPanel({
    super.key,
    required this.current,
    this.options = playerQualities,
    this.available,
  });
  final String current;
  final List<String> options;
  final Set<String>? available;

  @override
  Widget build(BuildContext context) => PlayerPanel(
    key: const ValueKey('quality-panel'),
    title: 'Quality',
    subtitle: 'Choose your video quality',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final quality in options) ...[
          if (quality != options.first) const SizedBox(height: 10),
          Pressable(
            key: ValueKey('quality-option-$quality'),
            label: '选择 $quality',
            selected: quality == current,
            onTap: available != null && !available!.contains(quality)
                ? null
                : () => Navigator.of(context).pop(quality),
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: quality == current
                    ? const Color(0x20ffffff)
                    : const Color(0x08ffffff),
                border: Border.all(
                  color: quality == current
                      ? const Color(0x70ffffff)
                      : const Color(0x0fffffff),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    quality,
                    style: type(
                      19,
                      weight: 650,
                      color: available == null || available!.contains(quality)
                          ? ink
                          : const Color(0xff656a70),
                    ),
                  ),
                  const Spacer(),
                  if (quality == current)
                    const Icon(Icons.check_circle_rounded, size: 23)
                  else
                    const Icon(
                      Icons.circle_outlined,
                      size: 22,
                      color: Color(0xff656a70),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
