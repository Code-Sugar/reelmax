import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'data.dart';
import 'design.dart';
import 'media.dart';
import 'vertical_swipe.dart';
import 'player_panels.dart';
import 'account_state.dart';
import 'localization.dart';

enum _Panel { episodes, quality }

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    this.sources = episodes,
    this.initialEpisode = 0,
  }) : assert(sources.length > 0),
       assert(initialEpisode >= 0 && initialEpisode < sources.length);
  final List<String> sources;
  final int initialEpisode;
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final controllers = <VideoPlayerController>[];
  final ready = <int>{};
  final failed = <int>{};
  late int episodeNumber = widget.initialEpisode + 3;
  bool playing = true, liked = false, collected = false;
  String quality = '4K';
  _Panel? panel;
  bool foreground = true;
  bool activating = false;
  double viewportHeight = 0;
  late final swipe = VerticalSwipeController(
    vsync: this,
    onChanged: activateEpisode,
  )..addListener(refreshSwipe);
  void refreshSwipe() => setState(() {});
  // Five selectable demo episodes reuse the three bundled video samples.
  int sourceFor(int number) => (number - 3) % widget.sources.length;
  int get episode => sourceFor(episodeNumber);
  int get availableEpisodes => AccountScope.maybeOf(context)?.plus == true
      ? playerEpisodeCount
      : unlockedEpisodeCount;
  int nextNumber(int step) =>
      (episodeNumber - 1 + step) % availableEpisodes + 1;
  VideoPlayerController get current => controllers[episode];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (var i = 0; i < widget.sources.length; i++) {
      controllers.add(
        VideoPlayerController.asset(
          'assets/${widget.sources[i]}',
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        ),
      );
      initialize(i);
    }
  }

  Future<void> initialize(int i) async {
    final controller = controllers[i];
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setVolume(0);
      await controller.setLooping(false);
      if (!mounted) return;
      controller.addListener(onVideo);
      setState(() => ready.add(i));
      if (i == episode && playing && foreground && panel == null) {
        await controller.play();
      }
    } catch (error) {
      if (mounted) setState(() => failed.add(i));
      debugPrint('Episode ${widget.sources[i]}: $error');
    }
  }

  void onVideo() {
    if (!mounted ||
        swipe.active ||
        activating ||
        panel != null ||
        !foreground ||
        !ready.contains(episode)) {
      return;
    }
    final value = current.value;
    if (value.isCompleted && playing) changeEpisode(1);
  }

  Future<void> togglePlay() async {
    if (swipe.active ||
        activating ||
        panel != null ||
        !ready.contains(episode)) {
      return;
    }
    setState(() => playing = !playing);
    if (playing) {
      await current.play();
    } else {
      await current.pause();
    }
  }

  void changeEpisode(int step) {
    if (swipe.active || activating || panel != null || viewportHeight <= 0) {
      return;
    }
    swipe.advance(step, viewportHeight);
  }

  Future<void> activateEpisode(int step) => selectEpisode(nextNumber(step));

  Future<void> selectEpisode(int number) async {
    if (activating ||
        number == episodeNumber ||
        number < 1 ||
        number > availableEpisodes) {
      return;
    }
    final previous = current;
    setState(() {
      episodeNumber = number;
      playing = true;
      activating = true;
    });
    await previous.pause();
    if (!mounted) return;
    if (ready.contains(episode)) {
      await current.seekTo(Duration.zero);
      if (!mounted) return;
      if (foreground && panel == null) await current.play();
      if (!mounted) return;
    }
    setState(() => activating = false);
  }

  Future<T?> showPanel<T>(_Panel kind, WidgetBuilder builder) async {
    if (panel != null || swipe.active || activating) return null;
    setState(() => panel = kind);
    T? selection;
    try {
      if (ready.contains(episode)) await current.pause();
      if (!mounted) return null;
      selection = await showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: .4),
        builder: builder,
      );
      return selection;
    } finally {
      if (mounted) {
        setState(() => panel = null);
        // A different selected episode starts itself; dismissing a panel keeps
        // the current video's position and the user's play/pause choice.
        final resume =
            kind != _Panel.episodes ||
            selection == null ||
            selection == episodeNumber;
        if (resume && playing && foreground && ready.contains(episode)) {
          await current.play();
        }
      }
    }
  }

  Future<void> openEpisodes() async {
    final number = await showPanel<int>(
      _Panel.episodes,
      (_) => EpisodePanel(current: episodeNumber, available: availableEpisodes),
    );
    if (mounted && number != null) await selectEpisode(number);
  }

  Future<void> openQuality() async {
    final selection = await showPanel<String>(
      _Panel.quality,
      (_) => QualityPanel(current: quality),
    );
    if (mounted && selection != null) setState(() => quality = selection);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground && panel == null && playing && ready.contains(episode)) {
      current.play();
    } else {
      for (final c in controllers) {
        c.pause();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    swipe.dispose();
    for (final controller in controllers) {
      controller.removeListener(onVideo);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xff15110e),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        viewportHeight = height;
        final target = sourceFor(nextNumber(swipe.direction));
        final safeBottom = MediaQuery.paddingOf(context).bottom;
        return GestureDetector(
          key: const ValueKey('player-swipe'),
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) {
            if (!activating) swipe.start();
          },
          onVerticalDragUpdate: (details) {
            if (!activating) swipe.update(details, height);
          },
          onVerticalDragEnd: (details) {
            if (!activating) swipe.end(details, height);
          },
          onVerticalDragCancel: swipe.cancel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: togglePlay,
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.translate(
                        key: const ValueKey('player-current-video'),
                        offset: Offset(0, swipe.offset),
                        child: _video(episode),
                      ),
                      if (swipe.active)
                        Transform.translate(
                          key: const ValueKey('player-adjacent-video'),
                          offset: Offset(
                            0,
                            swipe.direction * height + swipe.offset,
                          ),
                          child: _video(target),
                        ),
                    ],
                  ),
                ),
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x66040303),
                        Colors.transparent,
                        Colors.transparent,
                        Color(0x33070504),
                        Color(0x85050404),
                      ],
                      stops: [0, .22, .61, .78, 1],
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x14000000),
                          Colors.transparent,
                          Colors.transparent,
                          Color(0x40000000),
                        ],
                        stops: [0, .18, .74, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: pageTop(context),
                left: 16,
                right: 16,
                height: 50,
                child: _controlsOpacity(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: CircleControl(
                            label: '返回详情页',
                            size: 45,
                            onTap: () => Navigator.of(context).pop(),
                            child: const Glyph('detail-back', size: 26),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${tr(context, 'Episodes')} ${episodeNumber.toString().padLeft(2, '0')}',
                            style: type(20, weight: 690, spacing: -.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 52),
                    ],
                  ),
                ),
              ),
              Center(
                child: AnimatedOpacity(
                  opacity: playing ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: Pressable(
                    label: playing ? '暂停' : '播放',
                    onTap: togglePlay,
                    child: const SizedBox(
                      width: 70,
                      height: 76,
                      child: Center(child: Glyph('player-play', size: 60)),
                    ),
                  ),
                ),
              ),
              if (failed.contains(episode))
                Center(
                  child: Glass(
                    radius: 20,
                    dark: true,
                    padding: const EdgeInsets.all(18),
                    child: Text('视频暂时无法播放', style: type(14)),
                  ),
                ),
              Positioned(
                right: 13,
                bottom: (safeBottom + 70).clamp(92, double.infinity),
                child: _controlsOpacity(
                  child: Column(
                    children: [
                      _tool(
                        'like',
                        liked ? 'player-heart-filled' : 'player-heart',
                        '9m',
                        liked,
                        () => setState(() => liked = !liked),
                        label: liked ? '取消喜欢' : '喜欢',
                        red: liked,
                        feedback: true,
                      ),
                      const SizedBox(height: 12),
                      _tool(
                        'collect',
                        collected ? 'bookmark-active' : 'player-bookmark',
                        collected ? 'Saved' : 'Collect',
                        collected,
                        () => setState(() => collected = !collected),
                        label: collected ? '取消收藏' : '收藏',
                        tint: collected ? collectionYellow : null,
                        feedback: true,
                      ),
                      const SizedBox(height: 12),
                      _tool(
                        'list',
                        'player-queue',
                        'List',
                        panel == _Panel.episodes,
                        openEpisodes,
                        label: '剧集列表',
                      ),
                      const SizedBox(height: 12),
                      _tool(
                        'quality',
                        'player-4k',
                        quality,
                        panel == _Panel.quality,
                        openQuality,
                        label: '清晰度 $quality',
                        symbol: quality == '4K'
                            ? null
                            : SizedBox(
                                width: 30,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Divider(
                                      height: 5,
                                      thickness: 1.4,
                                      color: Colors.white,
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        quality,
                                        maxLines: 1,
                                        softWrap: false,
                                        style: type(
                                          quality.length > 3 ? 11 : 18,
                                          weight: 700,
                                        ),
                                      ),
                                    ),
                                    const Divider(
                                      height: 5,
                                      thickness: 1.4,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: (safeBottom + 2).clamp(16, double.infinity),
                left: 30,
                right: 30,
                height: 24,
                child: _controlsOpacity(
                  child: ready.contains(episode)
                      ? ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: current,
                          builder: (_, value, _) => SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              overlayShape: SliderComponentShape.noOverlay,
                              trackShape: const RectangularSliderTrackShape(),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 4.3,
                              ),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: const Color(0x57ffffff),
                              thumbColor: const Color(0xaaffffff),
                            ),
                            child: Slider(
                              semanticFormatterCallback: (value) =>
                                  '${(value * 100).round()}%',
                              value: value.duration.inMilliseconds > 0
                                  ? (value.position.inMilliseconds /
                                            value.duration.inMilliseconds)
                                        .clamp(0, 1)
                                  : 0,
                              onChanged: (ratio) => current.seekTo(
                                Duration(
                                  milliseconds:
                                      (value.duration.inMilliseconds * ratio)
                                          .round(),
                                ),
                              ),
                            ),
                          ),
                        )
                      : const Center(
                          child: LinearProgressIndicator(
                            value: 0,
                            minHeight: 3,
                            backgroundColor: Color(0x57ffffff),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  Widget _video(int index) => ready.contains(index)
      ? VideoCover(controller: controllers[index])
      : const Art('battle-of-two-cities.png');
  Widget _controlsOpacity({required Widget child}) => AnimatedOpacity(
    opacity: swipe.active ? .32 : 1,
    duration: const Duration(milliseconds: 220),
    child: child,
  );
  Widget _tool(
    String id,
    String icon,
    String text,
    bool active,
    VoidCallback onTap, {
    required String label,
    bool red = false,
    Color? tint,
    bool feedback = false,
    Widget? symbol,
  }) {
    final color = tint ?? (red ? const Color(0xffff4569) : Colors.white);
    final button = Pressable(
      key: ValueKey('player-$id'),
      label: label,
      selected: active,
      onTap: onTap,
      child: SizedBox(
        width: 60,
        height: 67,
        child: Column(
          children: [
            Glass(
              width: 48,
              height: 48,
              red: red,
              tint: tint,
              borderOpacity: active ? .72 : .36,
              child: Center(
                child: symbol ?? Glyph(icon, size: 25, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr(context, text),
              style: type(12, weight: 500, height: 1.1, color: color),
            ),
          ],
        ),
      ),
    );
    return feedback
        ? LikeFeedback(active: active, color: color, child: button)
        : button;
  }
}
