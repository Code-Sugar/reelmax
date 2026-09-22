import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'glass.dart';

export 'glass.dart';

const ink = Color(0xfff7f7f8);
const canvasColor = Color(0xff09090b);
const spring = Cubic(.16, 1.08, .25, 1);
const arrive = Cubic(.16, .9, .22, 1);
const motion = Duration(milliseconds: 280);
const pageEnterMotion = Duration(milliseconds: 320);
const pageExitMotion = Duration(milliseconds: 240);
const contentSwitchMotion = Duration(milliseconds: 360);

/// Keep each header close to the status bar without entering its safe area.
double pageTop(BuildContext context) => MediaQuery.paddingOf(context).top + 12;

TextStyle type(
  double size, {
  double weight = 400,
  Color color = ink,
  double height = 1,
  double spacing = 0,
  double slant = 0,
  double flare = 0,
  double volume = 0,
}) => TextStyle(
  fontFamily: 'Commissioner',
  fontSize: size,
  color: color,
  height: height,
  letterSpacing: spacing,
  // Weight comes from the variable axis; avoid synthetic bold on the font face.
  fontWeight: FontWeight.normal,
  fontVariations: [
    FontVariation('wght', weight),
    FontVariation('slnt', slant),
    FontVariation('FLAR', flare),
    FontVariation('VOLM', volume),
  ],
);

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class Art extends StatelessWidget {
  const Art(
    this.name, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.scale = 1,
    this.radius = 0,
    this.decodeToDisplaySize = true,
  });
  final String name;
  final double? width, height;
  final double scale, radius;
  final BoxFit fit;
  final Alignment alignment;

  /// Disable for artwork whose bounds continuously animate through many sizes.
  final bool decodeToDisplaySize;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: width,
      height: height,
      child: Transform.scale(
        scale: scale,
        child: name.isEmpty
            ? const ColoredBox(color: Color(0xff202722))
            : name.startsWith('http')
            ? LayoutBuilder(
                builder: (context, box) {
                  final pixels =
                      MediaQuery.devicePixelRatioOf(context) * scale.abs();
                  final pixelWidth = _decodeBucket(box.maxWidth * pixels);
                  final pixelHeight = _decodeBucket(box.maxHeight * pixels);
                  return Image(
                    image:
                        !decodeToDisplaySize ||
                            (pixelWidth == null && pixelHeight == null)
                        ? NetworkImage(name)
                        : ArtNetworkImage(
                            name,
                            pixelWidth: pixelWidth,
                            pixelHeight: pixelHeight,
                            fit: fit,
                          ),
                    fit: fit,
                    alignment: alignment,
                    width: width,
                    height: height,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(0xff202722),
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  );
                },
              )
            : Image.asset(
                'assets/$name',
                fit: fit,
                alignment: alignment,
                width: width,
                height: height,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
      ),
    ),
  );
}

// Nearby layout sizes share an image-cache entry instead of decoding a new
// bitmap for every pixel of an animated constraint. Round upward for sharpness.
int? _decodeBucket(double pixels) =>
    pixels.isFinite && pixels > 0 ? (pixels / 64).ceil() * 64 : null;

/// Decodes remote artwork to the pixels actually visible at its fitted size.
/// Unlike a two-dimensional ResizeImage, this keeps the source aspect ratio;
/// unlike ResizeImagePolicy.fit, cover crops retain enough pixels to stay sharp.
@immutable
class ArtNetworkImage extends ImageProvider<ArtNetworkImage> {
  const ArtNetworkImage(
    this.url, {
    this.pixelWidth,
    this.pixelHeight,
    this.fit = BoxFit.cover,
  }) : assert(pixelWidth != null || pixelHeight != null);

  final String url;
  final int? pixelWidth, pixelHeight;
  final BoxFit fit;

  @override
  Future<ArtNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  TargetImageSize decodeSize(int intrinsicWidth, int intrinsicHeight) {
    final source = Size(intrinsicWidth.toDouble(), intrinsicHeight.toDouble());
    double ratio;
    if (pixelWidth == null) {
      ratio = pixelHeight! / intrinsicHeight;
    } else if (pixelHeight == null) {
      ratio = pixelWidth! / intrinsicWidth;
    } else {
      final fitted = applyBoxFit(
        fit,
        source,
        Size(pixelWidth!.toDouble(), pixelHeight!.toDouble()),
      );
      ratio = math.max(
        fitted.destination.width / fitted.source.width,
        fitted.destination.height / fitted.source.height,
      );
    }
    ratio = ratio.clamp(0, 1);
    return TargetImageSize(
      width: math.max(1, (intrinsicWidth * ratio).ceil()),
      height: math.max(1, (intrinsicHeight * ratio).ceil()),
    );
  }

  @override
  ImageStreamCompleter loadImage(
    ArtNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    final source = NetworkImage(url);
    final completer = source.loadImage(
      source,
      (buffer, {getTargetSize}) =>
          decode(buffer, getTargetSize: key.decodeSize),
    );
    completer.addEphemeralErrorListener((_, _) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
    });
    return completer;
  }

  @override
  bool operator ==(Object other) =>
      other is ArtNetworkImage &&
      other.url == url &&
      other.pixelWidth == pixelWidth &&
      other.pixelHeight == pixelHeight &&
      other.fit == fit;

  @override
  int get hashCode => Object.hash(url, pixelWidth, pixelHeight, fit);
}

class Glyph extends StatelessWidget {
  const Glyph(this.name, {super.key, this.size = 24, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
  );
}

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.label,
    this.selected,
    this.radius = 24,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragStart,
  });
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final bool? selected;
  final double radius;
  final GestureDragUpdateCallback? onHorizontalDragUpdate, onVerticalDragUpdate;
  final GestureDragEndCallback? onHorizontalDragEnd, onVerticalDragEnd;
  final GestureDragStartCallback? onVerticalDragStart;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool down = false;
  void handleTap() {
    HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onTap != null,
    label: widget.label,
    selected: widget.selected,
    child: FocusableActionDetector(
      mouseCursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            handleTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => down = true),
        onTapCancel: () => setState(() => down = false),
        onTapUp: (_) => setState(() => down = false),
        onTap: widget.onTap == null ? null : handleTap,
        onHorizontalDragUpdate: widget.onHorizontalDragUpdate,
        onHorizontalDragEnd: widget.onHorizontalDragEnd,
        onVerticalDragStart: widget.onVerticalDragStart,
        onVerticalDragUpdate: widget.onVerticalDragUpdate,
        onVerticalDragEnd: widget.onVerticalDragEnd,
        child: AnimatedScale(
          scale: down ? .978 : 1,
          duration: Duration(milliseconds: down ? 90 : 200),
          curve: spring,
          child: widget.child,
        ),
      ),
    ),
  );
}

class CircleControl extends StatelessWidget {
  const CircleControl({
    super.key,
    required this.onTap,
    required this.child,
    required this.label,
    this.size = 42,
    this.red = false,
    this.variant = GlassVariant.control,
    this.tint,
  });
  final VoidCallback? onTap;
  final Widget child;
  final String label;
  final double size;
  final bool red;
  final GlassVariant variant;
  final Color? tint;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    label: label,
    child: Glass(
      variant: variant,
      width: size,
      height: size,
      red: red,
      tint: tint,
      child: Center(child: child),
    ),
  );
}

class StickyHeader extends SliverPersistentHeaderDelegate {
  StickyHeader({
    required this.height,
    required this.child,
    this.color = const Color(0xbb0c1110),
  });
  final double height;
  final Widget child;
  final Color color;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: overlapsContent ? 56 : 12,
        sigmaY: overlapsContent ? 56 : 12,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: overlapsContent ? color : color.withValues(alpha: .12),
        child: child,
      ),
    ),
  );
  @override
  bool shouldRebuild(covariant StickyHeader oldDelegate) => true;
}

class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: motion,
    curve: arrive,
    builder: (_, value, child) => Opacity(
      opacity: value.clamp(0, 1),
      child: Transform.translate(
        offset: Offset(0, 13 * (1 - value)),
        child: Transform.scale(scale: .986 + .014 * value, child: child),
      ),
    ),
    child: child,
  );
}

class LikeFeedback extends StatelessWidget {
  const LikeFeedback({
    super.key,
    required this.active,
    required this.child,
    this.color = const Color(0xffff2d55),
  });
  final bool active;
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(active),
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 720),
    curve: Curves.easeOutCubic,
    builder: (_, t, child) => CustomPaint(
      foregroundPainter: active ? _HeartParticles(t, color) : null,
      child: Transform.scale(
        scale: active ? 1 + math.sin(t * math.pi * 2) * .12 * (1 - t) : 1,
        child: child,
      ),
    ),
    child: child,
  );
}

class _HeartParticles extends CustomPainter {
  _HeartParticles(this.t, this.color);
  final double t;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final paint = Paint()..color = color.withValues(alpha: (1 - t) * .9);
    for (var i = 0; i < 8; i++) {
      final angle = math.pi + i * math.pi / 7;
      canvas.drawCircle(
        Offset(
          size.width / 2 + math.cos(angle) * (14 + 22 * t),
          size.height / 2 + math.sin(angle) * (14 + 26 * t),
        ),
        2 * (1 - t * .2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeartParticles oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}
