# Reel Max Android buffering policy

Vendored from video_player_android 2.9.5. Keep the upstream LICENSE and tests.
Both texture and platform-view player factories use ReelMaxLoadControl.

The app prepares adjacent episodes. Pausing ExoPlayer does not release its sample
buffers. On the reported emulator, concurrent buffering exhausted the 192 MiB
Java heap and caused a fatal OutOfMemoryError on ExoPlayer:Playback.

Use an 8 MiB sample-buffer target per player, prioritize size over time, buffer
2–8 seconds, and retain no back buffer. This is a loading threshold, not an
absolute cap on decoder, texture, manifest, or total process memory. A segment
can overshoot the threshold. Keep the Dart controller cache bounded as well.

API reference: https://developer.android.com/reference/androidx/media3/exoplayer/DefaultLoadControl.Builder

This Android native change requires a new build/run; hot reload is insufficient.
Do not patch the global Pub cache. Reapply and verify this policy when upgrading
the vendored dependency.
