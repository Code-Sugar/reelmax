package io.flutter.plugins.videoplayer;

import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DefaultLoadControl;

/** Bounds sample buffering when the app keeps adjacent episodes prepared. */
@UnstableApi
public final class ReelMaxLoadControl {
  private ReelMaxLoadControl() {}

  public static DefaultLoadControl create() {
    return new DefaultLoadControl.Builder()
        .setBufferDurationsMs(2000, 8000, 500, 1000)
        .setTargetBufferBytes(8 * 1024 * 1024)
        .setPrioritizeTimeOverSizeThresholds(false)
        .setBackBuffer(0, false)
        .build();
  }
}
