import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'account_state.dart';
import 'account_ui.dart';
import 'api.dart';
import 'data.dart';
import 'design.dart';
import 'detail.dart';
import 'live_catalog.dart';
import 'live_store.dart';
import 'localization.dart';
import 'media.dart';
import 'hls.dart';
import 'live_account.dart';
import 'live_bubbles.dart';
import 'player_panels.dart';
import 'speed_arrows.dart';

class _CachedEpisode {
  _CachedEpisode(this.controller, this.quality, this.qualities, this.paused);
  final VideoPlayerController controller;
  String quality;
  Map<String, Uri> qualities;
  bool paused;
}

class LivePlayer extends StatefulWidget {
  const LivePlayer({super.key, required this.skit, this.initialIndex = 0});
  final DramaInfo skit;
  final int initialIndex;
  @override
  State<LivePlayer> createState() => _LivePlayerState();
}

class _LivePlayerState extends State<LivePlayer> with WidgetsBindingObserver {
  late int index = widget.initialIndex;
  final pages = PageController();
  List<Json> episodes = [];
  VideoPlayerController? video;
  // Keep the current episode and its neighbours ready, with positions retained
  // separately when an older decoder is evicted.
  final cachedEpisodes = <int, _CachedEpisode>{};
  final preloading = <int, Future<void>>{};
  bool memoryConstrained = false;
  Future<void> preloadQueue = Future.value();
  final positions = <int, Duration>{};
  int? activeEpisodeId;
  String? cacheToken;
  bool cacheSessionSet = false;

  Duration resumePosition(VideoPlayerController controller) =>
      controller.value.isCompleted ||
          (controller.value.duration > Duration.zero &&
              controller.value.position >= controller.value.duration)
      ? Duration.zero
      : controller.value.position;

  void rememberActive() {
    final id = activeEpisodeId;
    final controller = video;
    if (id == null || controller == null) return;
    positions[id] = resumePosition(controller);
    final entry = cachedEpisodes[id];
    if (entry != null) {
      entry.quality = quality;
      entry.qualities = Map.of(qualities);
      entry.paused = paused;
    }
  }

  Future<void> trimCache(int limit) async {
    while (cachedEpisodes.length > limit) {
      final neighbours = {
        for (final i in [index - 1, index, index + 1])
          if (i >= 0 && i < episodes.length) integer(episodes[i]['id']),
      };
      final id =
          cachedEpisodes.keys
              .where((id) => id != activeEpisodeId && !neighbours.contains(id))
              .firstOrNull ??
          cachedEpisodes.keys.firstWhere((id) => id != activeEpisodeId);
      final entry = cachedEpisodes.remove(id)!;
      positions[id] = resumePosition(entry.controller);
      await entry.controller.dispose();
    }
  }

  void preloadNeighbours() {
    if (memoryConstrained) return;
    final attempt = generation;
    preloadQueue = preloadQueue.then((_) async {
      for (final offset in [1, -1]) {
        if (!mounted ||
            !foreground ||
            memoryConstrained ||
            attempt != generation)
          return;
        final neighbour = index + offset;
        if (neighbour < 0 || neighbour >= episodes.length) continue;
        final episode = episodes[neighbour];
        final id = integer(episode['id']);
        if (cachedEpisodes.containsKey(id) ||
            (integer(episode['needPay']) == 1 &&
                integer(episode['isUnlocked']) != 1) ||
            (integer(episode['isLogin']) == 1 && api.token == null)) {
          continue;
        }
        final pending = preloading.putIfAbsent(
          id,
          () => preloadEpisode(id, api),
        );
        await pending;
        if (preloading[id] == pending) preloading.remove(id);
      }
    });
  }

  Future<void> preloadEpisode(int id, SkitApi source) async {
    final token = source.token;
    bool relevant() =>
        mounted &&
        !memoryConstrained &&
        foreground &&
        source.token == token &&
        [index - 1, index, index + 1].any(
          (i) =>
              i >= 0 && i < episodes.length && integer(episodes[i]['id']) == id,
        );
    VideoPlayerController? controller;
    try {
      final result = await source.post('skit/play', {
        'skitId': widget.skit.serverId,
        'dramaId': id,
        'deviceId': source.deviceId,
      });
      if (!relevant()) return;
      final data = object(result);
      final url = result is String
          ? result
          : string(data['url'] ?? data['playUrl'] ?? data['playUrlPath']);
      if (url.isEmpty) return;
      final uri = source.base.resolve(url);
      if (!['http', 'https'].contains(uri.scheme)) return;
      await trimCache(2);
      if (!relevant()) return;
      controller = VideoPlayerController.networkUrl(
        uri,
        formatHint: videoFormatHint(uri),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      // Initializing prepares/buffers the source without background playback.
      await controller.initialize();
      if (!relevant()) return;
      final position = positions[id];
      if (position != null) await controller.seekTo(position);
      if (!relevant() || cachedEpisodes.containsKey(id)) return;
      cachedEpisodes[id] = _CachedEpisode(controller, 'Auto', {
        'Auto': uri,
      }, false);
      controller = null; // The cache now owns this controller.
      await trimCache(3);
      if (mounted) setState(() {});
    } catch (_) {
      // A speculative failure must not interrupt the episode being watched.
    } finally {
      await controller?.dispose();
    }
  }

  bool loading = true, mutating = false, paused = false, foreground = true;
  bool advancing = false;
  String? error;
  Future<void> Function()? retryAction;
  int generation = 0;
  bool started = false;
  Map<String, Uri> qualities = {};
  String quality = 'Auto';
  bool overlayOpen = false;
  Timer? controlsTimer;
  bool controlsVisible = true;
  bool scrubbing = false;
  VideoPlayerController? speedController;
  bool speedWasPaused = false;

  void revealControls() {
    controlsTimer?.cancel();
    controlsTimer = null;
    if (mounted && !controlsVisible) setState(() => controlsVisible = true);
  }

  void syncControls() {
    if (paused ||
        overlayOpen ||
        loading ||
        error != null ||
        !foreground ||
        scrubbing) {
      revealControls();
      return;
    }
    if (!controlsVisible || controlsTimer != null) return;
    controlsTimer = Timer(const Duration(seconds: 2), () {
      controlsTimer = null;
      if (mounted &&
          !paused &&
          !overlayOpen &&
          !scrubbing &&
          foreground &&
          !loading &&
          error == null) {
        setState(() => controlsVisible = false);
      }
    });
  }

  Future<void> startSpeed(LongPressStartDetails details) async {
    final width = MediaQuery.sizeOf(context).width;
    if (details.localPosition.dx > width * .28 &&
        details.localPosition.dx < width * .72) {
      return;
    }
    final controller = video;
    if (controller == null ||
        loading ||
        overlayOpen ||
        controller.value.hasError) {
      return;
    }
    speedWasPaused = paused;
    setState(() => speedController = controller);
    await controller.setPlaybackSpeed(2);
    if (mounted && speedController == controller) await controller.play();
  }

  void endSpeed() {
    final controller = speedController;
    if (controller == null) return;
    speedController = null;
    unawaited(controller.setPlaybackSpeed(1));
    if (speedWasPaused) unawaited(controller.pause());
    if (mounted) setState(() {});
    syncControls();
  }

  Widget chrome(Widget child) => IgnorePointer(
    ignoring: !controlsVisible,
    child: AnimatedOpacity(
      opacity: controlsVisible ? 1 : 0,
      duration: const Duration(milliseconds: 280),
      child: child,
    ),
  );
  bool loginPromptOpen = false;
  bool get needsLogin =>
      episodes.isNotEmpty &&
      integer(current['isLogin']) == 1 &&
      !AccountScope.of(context).signedIn;
  Json get current => episodes[index];
  SkitApi get api => AccountScope.of(context).api!;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      loadEpisodes();
    }
  }

  Future<void> loadEpisodes() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      episodes = objects(
        await api.get('skit/dramaList', {
          'id': widget.skit.serverId,
          'userId': AccountScope.of(context).user?.id ?? 0,
        }),
      );
      if (!mounted) return;
      if (episodes.isEmpty) {
        setState(() {
          loading = false;
          error = tr(context, 'No episodes available.', '暂无可播放剧集。');
        });
        return;
      }
      index = index.clamp(0, episodes.length - 1);
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && pages.hasClients) pages.jumpToPage(index);
      });
      await startVideo();
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  Future<void> startVideo() async {
    retryAction = null;
    endSpeed();
    revealControls();
    final attempt = ++generation;
    final id = integer(current['id']);
    rememberActive();
    final old = video;
    video = null;
    activeEpisodeId = null;
    old?.removeListener(onVideo);
    setState(() {
      loading = !cachedEpisodes.containsKey(id);
      error = null;
      paused = false;
      qualities = {};
      quality = 'Auto';
    });
    await old?.pause();
    if (!mounted || attempt != generation) return;
    if (cacheSessionSet && cacheToken != api.token) {
      final previous = cachedEpisodes.values.toList();
      cachedEpisodes.clear();
      positions.clear();
      for (final entry in previous) {
        await entry.controller.dispose();
      }
      if (!mounted || attempt != generation) return;
    }
    cacheToken = api.token;
    cacheSessionSet = true;
    if (integer(current['needPay']) == 1 &&
        integer(current['isUnlocked']) != 1) {
      setState(() => loading = false);
      return;
    }
    if (needsLogin) {
      setState(() => loading = false);
      await promptLogin();
      return;
    }
    // A swipe during preparation shares the same request and decoder.
    await preloading[id];
    if (!mounted || attempt != generation) return;
    final cached = cachedEpisodes.remove(id);
    if (cached != null && !cached.controller.value.hasError) {
      cachedEpisodes[id] = cached;
      // Clear the completed state before attaching the auto-advance listener.
      // Otherwise pause/play notifications can advance this episode again.
      if (cached.controller.value.isCompleted ||
          (cached.controller.value.duration > Duration.zero &&
              cached.controller.value.position >=
                  cached.controller.value.duration)) {
        await cached.controller.seekTo(Duration.zero);
        if (!mounted || attempt != generation) return;
        cached.paused = false;
        positions[id] = Duration.zero;
      }
      activeEpisodeId = id;
      video = cached.controller;
      video!.addListener(onVideo);
      setState(() {
        loading = false;
        paused = cached.paused;
        quality = cached.quality;
        qualities = Map.of(cached.qualities);
      });
      if (foreground && !paused && !overlayOpen) await video!.play();
      syncControls();
      if (cached.qualities.length == 1 && cached.quality == 'Auto') {
        unawaited(readQualities(cached.qualities['Auto']!, attempt));
      }
      preloadNeighbours();
      return;
    }
    if (cached != null) await cached.controller.dispose();
    await trimCache(2);
    if (!mounted || attempt != generation) return;
    setState(() => loading = true);
    VideoPlayerController? controller;
    try {
      final result = await api.post('skit/play', {
        'skitId': widget.skit.serverId,
        'dramaId': current['id'],
        'deviceId': api.deviceId,
      });
      if (!mounted || attempt != generation) return;
      final data = object(result);
      final url = result is String
          ? result
          : string(data['url'] ?? data['playUrl'] ?? data['playUrlPath']);
      if (url.isEmpty) throw const ApiException('播放接口未返回视频地址。');
      final uri = api.base.resolve(url);
      if (!['http', 'https'].contains(uri.scheme)) {
        throw const ApiException('播放地址无效。');
      }
      // Signed media URLs authorize playback themselves. Media3 propagates
      // httpHeaders to HLS child requests, including the external signed S3
      // segments; app Authorization there makes storage return HTTP 400.
      controller = VideoPlayerController.networkUrl(
        uri,
        formatHint: videoFormatHint(uri),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await controller.initialize();
      if (!mounted || attempt != generation) {
        await controller.dispose();
        return;
      }
      final savedPosition = positions[id];
      if (savedPosition != null) await controller.seekTo(savedPosition);
      if (!mounted || attempt != generation) {
        await controller.dispose();
        return;
      }
      qualities = {'Auto': uri};
      cachedEpisodes[id] = _CachedEpisode(
        controller,
        'Auto',
        Map.of(qualities),
        false,
      );
      activeEpisodeId = id;
      video = controller;
      controller.addListener(onVideo);
      if (foreground && !paused && !overlayOpen) await controller.play();
      if (!mounted || attempt != generation) return;
      setState(() => loading = false);
      syncControls();
      unawaited(recordView());
      unawaited(readQualities(uri, attempt));
      preloadNeighbours();
    } catch (e) {
      if (video != controller) await controller?.dispose();
      if (mounted && attempt == generation) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  Future<void> promptLogin() async {
    if (loginPromptOpen || !mounted) return;
    final attempt = generation;
    loginPromptOpen = true;
    overlayOpen = true;
    var signedIn = false;
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('episode-login-dialog'),
          title: Text(tr(context, 'Sign in to watch', '登录后观看')),
          content: Text(
            tr(
              context,
              'Sign in to continue watching this episode.',
              '登录后即可继续观看本集。',
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('episode-login-cancel'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr(context, 'Cancel', '取消')),
            ),
            TextButton(
              key: const ValueKey('episode-login-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr(context, 'Sign in', '去登录')),
            ),
          ],
        ),
      );
      if (confirm == true && mounted && attempt == generation) {
        signedIn = await requireAccount(context);
      }
    } finally {
      loginPromptOpen = false;
      overlayOpen = false;
    }
    if (mounted && attempt == generation && signedIn) {
      await loadEpisodes();
    }
  }

  Future<void> recordView() async {
    final body = {'skitId': widget.skit.serverId, 'dramaId': current['id']};
    try {
      await api.post('viewLog/record', body);
    } catch (_) {
      /* Playback remains usable when analytics is unavailable. */
    }
  }

  Future<void> readQualities(Uri uri, int attempt) async {
    try {
      final response = await api.client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (!mounted || attempt != generation) return;
      setState(() {
        quality = 'Auto';
        qualities = hlsVariants(response.body, uri);
      });
    } catch (_) {
      if (mounted && attempt == generation) {
        setState(() {
          quality = 'Auto';
          qualities = {'Auto': uri};
        });
      }
    }
  }

  Future<void> qualityPanel() async {
    if (video == null || overlayOpen) return;
    overlayOpen = true;
    await video?.pause();
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .4),
      builder: (_) => QualityPanel(
        current: quality,
        options: {'Auto', ...playerQualities, ...qualities.keys}.toList(),
        available: qualities.keys.toSet(),
      ),
    );
    overlayOpen = false;
    if (!mounted) return;
    if (selected == null ||
        selected == quality ||
        !qualities.containsKey(selected)) {
      if (!paused && foreground) await video?.play();
      return;
    }
    final position = video!.value.position;
    final id = activeEpisodeId!;
    positions[id] = position;
    cachedEpisodes.remove(id);
    final attempt = ++generation;
    final old = video!;
    old.removeListener(onVideo);
    video = null;
    setState(() {
      loading = true;
      error = null;
    });
    await old.dispose();
    if (!mounted || attempt != generation) return;
    final uri = qualities[selected]!;
    final replacement = VideoPlayerController.networkUrl(
      uri,
      formatHint: videoFormatHint(uri),
    );
    try {
      await replacement.initialize();
      if (!mounted || attempt != generation) {
        await replacement.dispose();
        return;
      }
      await replacement.seekTo(position);
      if (!mounted || attempt != generation) {
        await replacement.dispose();
        return;
      }
      cachedEpisodes[id] = _CachedEpisode(
        replacement,
        selected,
        Map.of(qualities),
        paused,
      );
      activeEpisodeId = id;
      video = replacement;
      replacement.addListener(onVideo);
      if (!paused && foreground) await replacement.play();
      if (mounted && attempt == generation) {
        setState(() {
          quality = selected;
          loading = false;
        });
        syncControls();
        preloadNeighbours();
      }
    } catch (e) {
      if (video != replacement) await replacement.dispose();
      if (mounted && attempt == generation) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  void onVideo() {
    if (!mounted || video == null) return;
    syncControls();
    if (video!.value.hasError && error == null) {
      setState(
        () => error = tr(
          context,
          'Video could not be loaded. Please retry.',
          '视频加载失败，请重试。',
        ),
      );
    }
    if (video!.value.isCompleted &&
        !loading &&
        activeEpisodeId == integer(current['id']) &&
        index + 1 < episodes.length &&
        !paused &&
        !advancing &&
        foreground &&
        !overlayOpen) {
      unawaited(advanceEpisode());
    }
  }

  Future<void> advanceEpisode() async {
    advancing = true;
    final attempt = generation;
    final next = episodes[index + 1];
    final id = integer(next['id']);
    try {
      // Leave the completed texture mounted while the next source prepares.
      final gated =
          (integer(next['needPay']) == 1 && integer(next['isUnlocked']) != 1) ||
          (integer(next['isLogin']) == 1 && api.token == null);
      if (!gated && !memoryConstrained) {
        if (!cachedEpisodes.containsKey(id)) {
          final pending = preloading.putIfAbsent(
            id,
            () => preloadEpisode(id, api),
          );
          await pending;
          if (preloading[id] == pending) preloading.remove(id);
        }
        if (!mounted || attempt != generation || !foreground || overlayOpen)
          return;
        final nextEntry = cachedEpisodes[id];
        if (nextEntry != null) {
          nextEntry.paused = false;
          if (nextEntry.controller.value.isCompleted) {
            await nextEntry.controller.seekTo(Duration.zero);
          }
        }
      }
      if (!mounted || attempt != generation || !foreground || overlayOpen)
        return;
      setState(() {});
      // Mount the prepared texture before beginning the page transition.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || attempt != generation || !pages.hasClients) return;
      await pages.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } finally {
      advancing = false;
    }
  }

  VideoPlayerController? pageVideo(int page) {
    final controller =
        cachedEpisodes[integer(episodes[page]['id'])]?.controller;
    return controller?.value.isInitialized == true &&
            controller?.value.hasError == false
        ? controller
        : null;
  }

  Future<void> action(String path, Json body, {bool reload = false}) async {
    final target = episodes
        .where((e) => e['id'] == body['dramaId'])
        .firstOrNull;
    if (mutating || !await requireAccount(context)) return;
    if (!mounted || mutating) return;
    final flag = switch (path) {
      'skit/likeDrama' => 'isLiked',
      'skit/collectDrama' => 'isCollected',
      _ => null,
    };
    final previous = flag == null ? null : target?[flag];
    setState(() {
      mutating = true;
      error = null;
      retryAction = null;
      if (flag != null) target?[flag] = body['status'];
    });
    try {
      await api.post(path, body);
      if (!mounted) return;
      if (reload) {
        await loadEpisodes();
        if (!mounted) return;
        await AccountScope.of(context).reloadProfile();
      }
    } catch (e) {
      // Restore the episode that was tapped, even if the viewer has moved on.
      if (flag != null) target?[flag] = previous;
      if (mounted && current['id'] == body['dramaId']) {
        setState(() {
          error = '$e';
          retryAction = () => action(path, body, reload: reload);
        });
      }
    } finally {
      if (mounted) setState(() => mutating = false);
    }
  }

  Future<void> unlock() async {
    if (mutating || episodes.isEmpty) return;
    await action('skit/buyDrama', {
      'skitId': widget.skit.serverId,
      'dramaId': current['id'],
    }, reload: true);
  }

  Future<void> panel() async {
    if (overlayOpen) return;
    overlayOpen = true;
    await video?.pause();
    if (!mounted) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .4),
      builder: (_) => EpisodePanel(
        current: index + 1,
        locks: episodes
            .map(
              (e) =>
                  integer(e['needPay']) == 1 && integer(e['isUnlocked']) != 1,
            )
            .toList(),
        allowLockedSelection: true,
      ),
    );
    overlayOpen = false;
    if (!mounted) return;
    if (selected != null && selected - 1 != index) {
      pages.jumpToPage(selected - 1);
    } else if (!paused && foreground) {
      await video?.play();
    }
  }

  Future<void> share() async {
    try {
      final result = await api.post('share/generate', {
        'skitId': widget.skit.serverId,
        'dramaId': current['id'],
      });
      final url = result is String
          ? result
          : string(object(result)['url'] ?? object(result)['shareUrl']);
      if (url.isEmpty) throw const ApiException('分享接口未返回链接。');
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(tr(context, 'Share link copied', '分享链接已复制')),
            content: SelectableText(url),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> more(String value) async {
    overlayOpen = true;
    await video?.pause();
    if (!mounted) return;
    if (value == 'share') {
      await share();
    } else {
      await Navigator.of(context).push(
        reelRoute(
          value == 'comments'
              ? LiveBubbles(
                  skitId: widget.skit.serverId!,
                  dramaId: integer(current['id']),
                  seconds: video?.value.position.inSeconds ?? 0,
                )
              : LiveFeedback(
                  kind: 'report',
                  skitId: widget.skit.serverId,
                  dramaId: integer(current['id']),
                ),
        ),
      );
    }
    overlayOpen = false;
    if (mounted && foreground && !paused) await video?.play();
  }

  @override
  void didHaveMemoryPressure() {
    // Stop speculative buffering for this page after an OS memory warning.
    // Positions remain available if an evicted episode is opened again.
    memoryConstrained = true;
    unawaited(releaseInactiveEpisodes());
  }

  Future<void> releaseInactiveEpisodes() async {
    final inactive = cachedEpisodes.keys
        .where((id) => id != activeEpisodeId)
        .toList();
    final removed = <_CachedEpisode>[];
    for (final id in inactive) {
      final entry = cachedEpisodes.remove(id)!;
      positions[id] = resumePosition(entry.controller);
      removed.add(entry);
    }
    if (mounted) setState(() {});
    await Future.wait(removed.map((entry) => entry.controller.dispose()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) endSpeed();
    revealControls();
    if (foreground && !paused && !overlayOpen) {
      video?.play();
      preloadNeighbours();
    } else {
      video?.pause();
    }
  }

  @override
  void dispose() {
    controlsTimer?.cancel();
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    video?.removeListener(onVideo);
    for (final entry in cachedEpisodes.values) {
      unawaited(entry.controller.dispose());
    }
    cachedEpisodes.clear();
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (episodes.isNotEmpty)
          PageView.builder(
            controller: pages,
            scrollDirection: Axis.vertical,
            itemCount: episodes.length,
            onPageChanged: (value) {
              if (index != value) {
                index = value;
                startVideo();
              }
            },
            itemBuilder: (_, i) => GestureDetector(
              key: ValueKey('live-video-gesture-$i'),
              behavior: HitTestBehavior.opaque,
              onLongPressStart: i == index ? startSpeed : null,
              onLongPressEnd: (_) => endSpeed(),
              onLongPressCancel: endSpeed,
              onTap: i == index && needsLogin
                  ? promptLogin
                  : i == index && video != null
                  ? () {
                      revealControls();
                      setState(() => paused = !paused);
                      paused ? video!.pause() : video!.play();
                    }
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Art(string(episodes[i]['cover'])),
                  if (pageVideo(i) case final controller?)
                    VideoCover(controller: controller),
                  if (i == index &&
                      speedController == null &&
                      (paused || (!loading && needsLogin)))
                    const Center(
                      child: Icon(Icons.play_arrow_rounded, size: 86),
                    ),
                ],
              ),
            ),
          ),
        Positioned(
          top: pageTop(context),
          left: 18,
          child: chrome(
            CircleControl(
              label: 'Back',
              size: 44,
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.chevron_left),
            ),
          ),
        ),
        Positioned(
          top: pageTop(context) + 9,
          left: 78,
          right: 78,
          child: chrome(
            Text(
              'Episodes ${(index + 1).toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: type(20, weight: 750),
            ),
          ),
        ),
        if (episodes.isNotEmpty)
          Positioned(
            top: pageTop(context),
            right: 12,
            child: chrome(
              PopupMenuButton<String>(
                onOpened: () {
                  overlayOpen = true;
                  revealControls();
                },
                onCanceled: () {
                  overlayOpen = false;
                  syncControls();
                },
                icon: const Icon(Icons.more_horiz),
                onSelected: more,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'share',
                    child: Text(tr(context, 'Share', '分享')),
                  ),
                  PopupMenuItem(
                    value: 'comments',
                    child: Text(tr(context, 'Comments', '弹幕')),
                  ),
                  PopupMenuItem(
                    value: 'report',
                    child: Text(tr(context, 'Report', '举报')),
                  ),
                ],
              ),
            ),
          ),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (episodes.isNotEmpty &&
            !loading &&
            integer(current['needPay']) == 1 &&
            integer(current['isUnlocked']) != 1)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 55),
              child: AccountCard(
                key: const ValueKey('episode-unlock-card'),
                backgroundColor: const Color(0xf21b1e20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 36),
                    const SizedBox(height: 18),
                    AccountButton(
                      text: tr(
                        context,
                        'Unlock · ${current['coin']} coins',
                        '解锁 · ${current['coin']} 金币',
                      ),
                      onTap: mutating ? null : unlock,
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .push(reelRoute(const LiveStorePage()))
                          .then((_) {
                            if (mounted) loadEpisodes();
                          }),
                      child: Text(tr(context, 'Membership & coins', '会员与金币')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (episodes.isNotEmpty &&
            !(integer(current['needPay']) == 1 &&
                integer(current['isUnlocked']) != 1) &&
            !needsLogin)
          Positioned(
            right: 18,
            bottom: 105,
            child: chrome(
              Column(
                children: [
                  _control(
                    Icons.favorite,
                    'Like',
                    integer(current['isLiked']) == 1
                        ? const Color(0xffff456b)
                        : ink,
                    () => action('skit/likeDrama', {
                      'dramaId': current['id'],
                      'status': integer(current['isLiked']) == 1 ? 0 : 1,
                    }),
                    active: integer(current['isLiked']) == 1,
                    red: integer(current['isLiked']) == 1,
                    symbol: Glyph(
                      integer(current['isLiked']) == 1
                          ? 'player-heart-filled'
                          : 'player-heart',
                      size: 25,
                      color: integer(current['isLiked']) == 1
                          ? const Color(0xffff456b)
                          : ink,
                    ),
                  ),
                  _control(
                    Icons.bookmark,
                    integer(current['isCollected']) == 1 ? 'Saved' : 'Collect',
                    integer(current['isCollected']) == 1 ? accountGold : ink,
                    () => action('skit/collectDrama', {
                      'dramaId': current['id'],
                      'status': integer(current['isCollected']) == 1 ? 0 : 1,
                    }),
                    active: integer(current['isCollected']) == 1,
                    tint: integer(current['isCollected']) == 1
                        ? collectionYellow
                        : null,
                    symbol: Glyph(
                      integer(current['isCollected']) == 1
                          ? 'bookmark-active'
                          : 'player-bookmark',
                      size: 25,
                      color: integer(current['isCollected']) == 1
                          ? collectionYellow
                          : ink,
                    ),
                  ),
                  _control(
                    Icons.playlist_play,
                    'List',
                    ink,
                    panel,
                    symbol: const Glyph('player-queue', size: 25),
                  ),
                  _control(
                    Icons.high_quality_outlined,
                    quality,
                    ink,
                    qualityPanel,
                    symbol: quality == '4K'
                        ? const Glyph('player-4k', size: 25)
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
        if (error != null)
          Positioned(
            left: 24,
            right: 90,
            bottom: 145,
            child: AccountCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!, style: type(12), textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () async {
                      if (retryAction != null) {
                        await retryAction!();
                        return;
                      }
                      if (episodes.isNotEmpty &&
                          integer(current['isLogin']) == 1 &&
                          !AccountScope.of(context).signedIn) {
                        if (!await requireAccount(context)) return;
                      }
                      if (mounted) loadEpisodes();
                    },
                    child: Text(tr(context, 'Retry', '重试')),
                  ),
                ],
              ),
            ),
          ),
        if (video?.value.isInitialized == true)
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.paddingOf(context).bottom + 25,
            child: chrome(
              Listener(
                onPointerDown: (_) {
                  scrubbing = true;
                  revealControls();
                },
                onPointerUp: (_) {
                  scrubbing = false;
                  syncControls();
                },
                onPointerCancel: (_) {
                  scrubbing = false;
                  syncControls();
                },
                child: VideoProgressIndicator(
                  video!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 24,
          right: 24,
          bottom: MediaQuery.paddingOf(context).bottom + 52,
          child: IgnorePointer(
            child: AnimatedOpacity(
              key: const ValueKey('double-speed-indicator'),
              opacity: speedController == null ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: Center(
                child: Glass(
                  dark: true,
                  radius: 24,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SpeedArrows(active: speedController != null),
                      const SizedBox(width: 6),
                      Text(
                        tr(context, '2x speed', '2 倍速播放'),
                        style: type(13, weight: 600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _control(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap, {
    Widget? symbol,
    bool active = false,
    bool red = false,
    Color? tint,
  }) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      children: [
        LikeFeedback(
          active: active,
          color: color,
          child: CircleControl(
            label: label,
            size: 47,
            red: red,
            tint: tint,
            onTap: mutating
                ? null
                : () {
                    revealControls();
                    onTap();
                    syncControls();
                  },
            child: symbol ?? Icon(icon, color: color, size: 25),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: type(11, color: color)),
      ],
    ),
  );
}
