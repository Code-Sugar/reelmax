import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';
import 'media.dart';

/// A bounded decoder window shared by the hero, Next card and its animation.
class HomeVideoPool extends ChangeNotifier with WidgetsBindingObserver {
  HomeVideoPool() {
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    // A visible Android view (notably an emulator on startup/hot restart) can
    // already be inactive when this observer is attached, without a later
    // resumed event. Do not leave that first visible home window uninitialized.
    // Subsequent inactive events still pause normally below.
    foreground =
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.detached;
  }
  final _controllers = <String, VideoPlayerController>{};
  final _positions = <String, Duration>{};
  final _retries = <String, int>{};
  final _retryTimers = <String, Timer>{};
  List<String> _window = [];
  Set<String> _playing = {};
  bool foreground = true, _closed = false, _running = false;
  bool _interrupted = false;
  int _revision = 0;

  VideoPlayerController? controllerFor(String source) {
    final value = _controllers[source];
    return value != null && value.value.isInitialized && !value.value.hasError
        ? value
        : null;
  }

  void configure(List<String> window, Set<String> playing) {
    if (_closed) return;
    final next = window.where((s) => s.isNotEmpty).toSet().take(3).toList();
    // Also repair a pool created by the previous code after a hot reload.
    // A real inactive callback sets _interrupted, so it is never unpaused here.
    final visibleAtCreation =
        !foreground &&
        !_interrupted &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.inactive &&
        playing.isNotEmpty;
    if (listEquals(next, _window) &&
        setEquals(playing, _playing) &&
        !visibleAtCreation) {
      return;
    }
    if (visibleAtCreation) foreground = true;
    _window = next;
    _playing = playing;
    for (final source in _retries.keys.toList()) {
      if (!next.contains(source)) {
        _retries.remove(source);
        _retryTimers.remove(source)?.cancel();
      }
    }
    _revision++;
    _pauseHidden();
    _schedule();
  }

  void _pauseHidden() {
    for (final entry in _controllers.entries.toList()) {
      if (!foreground || !_playing.contains(entry.key)) {
        unawaited(
          entry.value.pause().catchError((Object error) {
            _failed(entry.key, entry.value, error);
          }),
        );
      }
    }
  }

  void _schedule() {
    if (_closed || _running) return;
    _running = true;
    scheduleMicrotask(_reconcile);
  }

  Future<void> _release(VideoPlayerController controller) async {
    // Failed native creation can leave the plugin's creation completer pending.
    // It must never hold up every other video in the home window.
    final disposal = controller.dispose();
    try {
      await disposal.timeout(const Duration(seconds: 1));
    } catch (_) {
      // Disposal continues independently if the native reply arrives late.
    }
  }

  void _failed(String source, VideoPlayerController controller, Object error) {
    if (_closed || _controllers[source] != controller) return;
    _controllers.remove(source);
    unawaited(_release(controller));
    scheduleMicrotask(() {
      if (!_closed) notifyListeners();
    });
    final attempt = (_retries[source] ?? 0) + 1;
    _retries[source] = attempt;
    debugPrint('Home preview failed (${error.runtimeType}), attempt $attempt');
    if (attempt > 3 || !_window.contains(source)) return;
    _retryTimers.remove(source)?.cancel();
    _retryTimers[source] = Timer(Duration(seconds: attempt), () {
      _retryTimers.remove(source);
      if (_closed || !foreground || !_window.contains(source)) return;
      _revision++;
      _schedule();
    });
  }

  Future<void> _reconcile() async {
    var revision = -1;
    try {
      do {
        revision = _revision;
        final wanted = foreground
            ? List.of(_window)
            : _interrupted
            ? _window.where(_controllers.containsKey).toList()
            : <String>[];
        // Pause hidden content before network/decoder initialization work.
        for (final item in _controllers.entries.toList()) {
          if (_closed) return;
          if (!wanted.contains(item.key) || !_playing.contains(item.key)) {
            await item.value.pause();
          }
        }
        for (final source in _controllers.keys.toList()) {
          if (_closed) return;
          if (wanted.contains(source)) continue;
          final controller = _controllers.remove(source);
          if (controller == null) continue;
          _positions.remove(source);
          _positions[source] = controller.value.position;
          if (_positions.length > 50) _positions.remove(_positions.keys.first);
          if (!_closed) notifyListeners();
          await _release(controller);
        }
        if (_closed) return;
        if (revision != _revision) continue;
        for (final source in wanted) {
          if (_closed || revision != _revision) break;
          var controller = _controllers[source];
          if (controller == null) {
            if (_retryTimers.containsKey(source) ||
                (_retries[source] ?? 0) > 3) {
              continue;
            }
            controller = source.startsWith('http')
                ? VideoPlayerController.networkUrl(
                    Uri.parse(source),
                    formatHint: videoFormatHint(Uri.parse(source)),
                    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
                  )
                : VideoPlayerController.asset(
                    'assets/$source',
                    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
                  );
            _controllers[source] = controller;
            try {
              await controller.initialize().timeout(
                const Duration(seconds: 15),
              );
              if (_closed) break;
              await controller.setVolume(0);
              await controller.setLooping(true);
              final position = _positions[source];
              if (position != null) await controller.seekTo(position);
              if (_closed) break;
              controller.addListener(() {
                if (controller!.value.hasError) {
                  _failed(source, controller, StateError('Playback failed'));
                }
              });
              notifyListeners();
              if (revision != _revision) break;
            } catch (error) {
              _failed(source, controller, error);
              continue;
            }
          }
          if (_closed || revision != _revision) break;
          try {
            if (foreground && _playing.contains(source)) {
              if (!controller.value.isPlaying) await controller.play();
            } else if (controller.value.isPlaying) {
              await controller.pause();
            }
          } catch (error) {
            _failed(source, controller, error);
          }
        }
      } while (!_closed && revision != _revision);
    } finally {
      _running = false;
      if (!_closed && revision != _revision) _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    // A notification shade pauses playback without tearing down decoders.
    _interrupted = state == AppLifecycleState.inactive;
    _revision++;
    _pauseHidden();
    _schedule();
  }

  @override
  void dispose() {
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    for (final controller in _controllers.values) {
      unawaited(_release(controller));
    }
    _controllers.clear();
    super.dispose();
  }
}
