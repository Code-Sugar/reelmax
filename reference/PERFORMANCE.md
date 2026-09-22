# Playback performance

## Resource limits

- The home hero, Next card and expansion animation share `HomeVideoPool`.
  Only the current item and its two neighbours own native decoders (at most 3),
  independent of catalog size. Only visible previews play.
- Leaving the home tab or opening another route releases home decoders.
  The widget state, catalog data and recent playback positions remain cached.
- Episode playback retains its existing current/adjacent episode cache while
  foregrounded. Entering the background releases adjacent decoders and
  invalidates earlier speculative requests, keeping the current position.
- Quality discovery skips MP4 media, reads at most 256 KiB of HLS playlist data
  and remembers successfully parsed results for each cached episode.
- Remote artwork decodes to its fitted pixel size, including device pixel ratio
  and explicit zoom. Sizes are rounded upward in 64-pixel buckets for cache reuse.

## Automated verification

`flutter test` covers bounded decoder counts through repeated home transitions,
Next decoder reuse, off-page/background release, position restoration, media
request counts, stale preload rejection and image decode dimensions. Existing
UI/player tests cover the original interactions and layouts.

These tests use a fake video platform. They cannot measure temperature, native
decoder frame delivery, CPU/GPU load or real network buffering.

## On-device comparison

Use a physical Android device and an iPhone with the same video sequence,
brightness, network, starting temperature and power state for both versions.
Run in **profile** mode for frame/CPU/memory analysis, then confirm the user
experience with a **release** build. Do not compare emulator/debug heat with
release behaviour.

1. Keep the home page visible for two minutes, then switch through 20 items.
2. Play episodes continuously for ten minutes, switching forward/backward and
   scrubbing periodically. Include both the expanded and collapsed Next card.
3. Visit the other tabs and details, background for one minute, then return.
4. Record frame build/raster p95, frames above the display refresh budget,
   CPU/GPU use, process/graphics memory and thermal state at fixed intervals.
   Check that decoder/memory counts plateau instead of growing each loop.
5. Verify no background audio, retained playback position, working quality
   selection and the existing next-episode preload/automatic transition.

Flutter reference: https://docs.flutter.dev/perf/ui-performance

Potential follow-up work should be driven by these measurements: large catalog
lists currently build all cards, and glass backgrounds incur backdrop-filter
GPU work. Neither the layouts nor glass styling were changed in this pass.
