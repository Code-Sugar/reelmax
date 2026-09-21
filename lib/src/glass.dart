import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Each surface follows its own material in the prototype's CSS.
enum GlassVariant { control, filter, play, navigation, selection }

class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 99,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.active = false,
    this.red = false,
    this.tint,
    this.blur = 9,
    this.borderOpacity = .44,
    this.dark = false,
    this.variant = GlassVariant.control,
  });

  final Widget child;
  final double radius, blur, borderOpacity;
  final double? width, height;
  final EdgeInsets padding;
  final bool active, red, dark;
  final Color? tint;
  final GlassVariant variant;

  @override
  Widget build(BuildContext context) {
    final material = _GlassMaterial(
      variant,
      active,
      red,
      dark,
      borderOpacity,
      tint,
    );
    final border = BorderRadius.circular(radius);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        foregroundPainter: _GlassShadowPainter(material, radius),
        child: ClipRRect(
          borderRadius: border,
          child: BackdropFilter(
            // Filter the sampled background only, keeping text and SVGs crisp.
            filter: ui.ImageFilter.compose(
              outer: ColorFilter.matrix(
                _colorMatrix(
                  material.saturation,
                  material.brightness,
                  material.contrast,
                ),
              ),
              inner: ui.ImageFilter.blur(
                sigmaX: material.blur ?? blur,
                sigmaY: material.blur ?? blur,
              ),
            ),
            child: CustomPaint(
              painter: _GlassPainter(material, radius),
              child: Padding(
                padding: padding + const EdgeInsets.all(1),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<double> _colorMatrix(
  double saturation,
  double brightness,
  double contrast,
) {
  final r = .213 * (1 - saturation);
  final g = .715 * (1 - saturation);
  final b = .072 * (1 - saturation);
  final gain = brightness * contrast;
  final offset = 255 * (1 - contrast) / 2;
  return [
    (r + saturation) * gain,
    g * gain,
    b * gain,
    0,
    offset,
    r * gain,
    (g + saturation) * gain,
    b * gain,
    0,
    offset,
    r * gain,
    g * gain,
    (b + saturation) * gain,
    0,
    offset,
    0,
    0,
    0,
    1,
    0,
  ];
}

class _GlassMaterial {
  const _GlassMaterial(
    this.variant,
    this.active,
    this.red,
    this.dark,
    this.borderOpacity,
    this.tint,
  );
  final GlassVariant variant;
  final bool active, red, dark;
  final double borderOpacity;
  final Color? tint;
  bool get play => variant == GlassVariant.play;
  bool get navigation => variant == GlassVariant.navigation;
  bool get selection => variant == GlassVariant.selection;
  bool get filter => variant == GlassVariant.filter;
  bool get white => active && !play;

  double? get blur => navigation
      ? 12
      : play
      ? 8
      : filter
      ? 10
      : null;
  double get saturation => navigation
      ? 1.85
      : play
      ? 1.65
      : filter
      ? 1.75
      : 1.8;
  double get brightness => dark
      ? 1
      : navigation
      ? 1.07
      : 1.06;
  double get contrast => navigation ? 1.04 : 1;

  List<Color> get colors {
    if (dark) return const [Color(0xeb080809), Color(0xeb080809)];
    if (play) return const [Color(0xf5ffffff), Color(0xc2ebf2f4)];
    if (white) {
      return const [Colors.white, Color(0xe8f8f9fa), Color(0xe0edf1f2)];
    }
    if (navigation) {
      return const [Color(0x2effffff), Color(0x0dffffff), Color(0x6b070a0b)];
    }
    if (selection) return const [Color(0x33ffffff), Color(0x11ffffff)];
    if (red) {
      return const [Color(0x33ffffff), Color(0x29ff2d55), Color(0x6118080c)];
    }
    if (tint != null) {
      return [
        const Color(0x33ffffff),
        tint!.withValues(alpha: .19),
        Color.lerp(Colors.black, tint, .14)!.withValues(alpha: .40),
      ];
    }
    if (filter) {
      return const [Color(0x2effffff), Color(0x0bffffff), Color(0x24070a0c)];
    }
    return const [Color(0x38ffffff), Color(0x0effffff), Color(0x33070c0d)];
  }

  List<double>? get stops => colors.length == 2
      ? null
      : white
      ? const [0, .55, 1]
      : navigation
      ? const [0, .36, .88]
      : filter
      ? const [0, .46, 1]
      : const [0, .48, 1];

  Color get borderColor => dark
      ? const Color(0x14ffffff)
      : red
      ? const Color(0xb8ff5b79)
      : tint != null
      ? tint!.withValues(alpha: .8)
      : play
      ? const Color(0xc7ffffff)
      : white
      ? Colors.white
      : Colors.white.withValues(alpha: borderOpacity);

  List<BoxShadow> get shadows => [
    BoxShadow(
      color: Colors.black.withValues(
        alpha: navigation
            ? .48
            : play
            ? .30
            : selection
            ? .27
            : white
            ? .25
            : filter
            ? .22
            : .24,
      ),
      offset: Offset(
        0,
        navigation
            ? 16
            : play
            ? 9
            : selection || white
            ? 7
            : 8,
      ),
      blurRadius: navigation
          ? 42
          : selection
          ? 18
          : play || filter
          ? 24
          : 22,
    ),
    if (!dark)
      BoxShadow(
        color: tint != null
            ? tint!.withValues(alpha: .18)
            : white
            ? const Color(0x4ddef8ff)
            : play
            ? const Color(0x1fffffff)
            : navigation
            ? const Color(0x149ae2d9)
            : selection
            ? const Color(0x1abef4f1)
            : const Color(0x0fccf5ec),
        blurRadius: white || navigation
            ? 18
            : selection
            ? 12
            : play
            ? 15
            : filter
            ? 13
            : 14,
      ),
  ];
}

class _GlassShadowPainter extends CustomPainter {
  const _GlassShadowPainter(this.material, this.radius);
  final _GlassMaterial material;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final outline = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    // CSS outer shadows exclude the box interior. A BoxDecoration shadow fills
    // that interior, tinting a translucent lens dark and flattening its light.
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(150))
      ..addRRect(outline);
    canvas.save();
    canvas.clipPath(outside);
    for (final shadow in material.shadows.reversed) {
      canvas.drawRRect(
        outline.shift(shadow.offset),
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            shadow.blurRadius / 2,
          ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassShadowPainter oldDelegate) =>
      radius != oldDelegate.radius ||
      material.variant != oldDelegate.material.variant ||
      material.active != oldDelegate.material.active ||
      material.red != oldDelegate.material.red ||
      material.tint != oldDelegate.material.tint ||
      material.dark != oldDelegate.material.dark;
}

class _GlassPainter extends CustomPainter {
  const _GlassPainter(this.material, this.radius);
  final _GlassMaterial material;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final outline = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final face = outline.deflate(1);
    final m = material;

    canvas.save();
    canvas.clipRRect(outline);
    canvas.drawRRect(
      outline,
      Paint()
        ..shader = _cssLinear(
          rect,
          m.navigation ? 148 : 145,
          m.colors,
          m.stops,
        ),
    );

    if (!m.dark) {
      if (m.navigation) {
        // The broad highlight and the lower aqua reflection belong to the bar.
        canvas.drawRRect(
          face,
          Paint()
            ..shader = _cssLinear(
              rect,
              116,
              const [
                Color(0x52ffffff),
                Color(0x00ffffff),
                Color(0x00a4ecdf),
                Color(0x29a4ecdf),
              ],
              const [0, .26, .62, 1],
            ),
        );
        _radial(
          canvas,
          face,
          const Offset(.18, 0),
          const Color(0x52ffffff),
          .34,
        );
        canvas.drawOval(
          Rect.fromLTWH(
            size.width * .08,
            size.height - 18,
            size.width * .84,
            34,
          ),
          Paint()
            ..color = const Color(0x298fe8d6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
        );
      } else if (m.selection) {
        // A separate convex lens, not the same dark material as the bar.
        _radial(
          canvas,
          face,
          const Offset(.48, -.06),
          const Color(0x6bffffff),
          .48,
        );
      } else if (m.filter || (!m.white && !m.play)) {
        canvas.drawRRect(
          face,
          Paint()
            ..shader = _cssLinear(rect, 118, [
              Colors.white.withValues(alpha: m.filter ? .373 : .428),
              const Color(0x00ffffff),
              const Color(0x00aaefe4),
              m.filter ? const Color(0x22b0f2e5) : const Color(0x2aaaefe4),
            ], m.filter ? const [0, .26, .68, 1] : const [0, .27, .67, 1]),
        );
      }

      // CSS inset shadows are an outside mask shifted inside the clipped face.
      // Paint the darker lower edge first, then the soft white upper edge.
      _insetShadow(
        canvas,
        face,
        Offset(0, m.play || m.white || m.navigation || m.selection ? -2 : -1.5),
        m.play || m.white || m.selection
            ? 5
            : m.navigation
            ? 4
            : 3,
        m.white
            ? const Color(0x2e768b94)
            : m.play
            ? const Color(0x2b4d666d)
            : m.selection
            ? const Color(0x38081519)
            : const Color(0x3d010a0c),
      );
      _insetShadow(
        canvas,
        face,
        Offset(
          0,
          m.play
              ? 1.5
              : m.navigation
              ? 1.4
              : 1.2,
        ),
        m.play || m.white ? 2 : 1,
        m.play || m.white
            ? Colors.white
            : m.filter
            ? const Color(0x94ffffff)
            : m.selection
            ? const Color(0x9cffffff)
            : m.navigation
            ? const Color(0x99ffffff)
            : const Color(0xadffffff),
      );
    }

    canvas.drawRRect(
      outline.deflate(.5),
      Paint()
        ..color = m.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  void _radial(
    Canvas canvas,
    RRect face,
    Offset fraction,
    Color color,
    double stop,
  ) {
    final rect = face.outerRect;
    final center = Offset(
      rect.left + rect.width * fraction.dx,
      rect.top + rect.height * fraction.dy,
    );
    final extent = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ].map((corner) => (corner - center).distance).reduce(math.max);
    canvas.drawRRect(
      face,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          extent,
          [color, color.withValues(alpha: 0)],
          [0, stop],
        ),
    );
  }

  void _insetShadow(
    Canvas canvas,
    RRect face,
    Offset offset,
    double blur,
    Color color,
  ) {
    final outer = face.outerRect.inflate(blur * 3 + offset.distance + 2);
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(outer)
      ..addRRect(face.shift(offset));
    canvas.save();
    canvas.clipRRect(face);
    canvas.drawPath(
      mask,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
    );
    canvas.restore();
  }

  /// CSS angles use 0° at the top; alignment-based gradients distort the angle
  /// on wide capsules. Calculate the CSS gradient line in physical coordinates.
  ui.Shader _cssLinear(
    Rect rect,
    double degrees,
    List<Color> colors,
    List<double>? stops,
  ) {
    final radians = degrees * math.pi / 180;
    final direction = Offset(math.sin(radians), -math.cos(radians));
    final length =
        rect.width * direction.dx.abs() + rect.height * direction.dy.abs();
    return ui.Gradient.linear(
      rect.center - direction * (length / 2),
      rect.center + direction * (length / 2),
      colors,
      stops,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassPainter oldDelegate) =>
      radius != oldDelegate.radius ||
      material.variant != oldDelegate.material.variant ||
      material.active != oldDelegate.material.active ||
      material.red != oldDelegate.material.red ||
      material.tint != oldDelegate.material.tint ||
      material.dark != oldDelegate.material.dark ||
      material.borderOpacity != oldDelegate.material.borderOpacity;
}
