import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Liquid Glass material, per Apple's iOS 26 design language.
///
/// The thing that separates real glass from a flat translucent rectangle is
/// the **edge**: a uniform 1px border reads as tinted film, while glass is
/// brightest where light strikes it (conventionally the top) and carries a
/// darker rim on the opposite side where it turns away from the light.
///
/// So this paints, in order:
///   1. a blurred, saturated sample of whatever is behind it,
///   2. a translucent tint that keeps text contrast predictable,
///   3. an inner top highlight — the specular catch,
///   4. a hairline rim that fades from bright at the top to dark at the bottom,
///   5. a soft drop shadow that lifts the panel off the page.
///
/// Saturating the backdrop (rather than only blurring it) is what keeps colour
/// alive behind the glass; a plain blur is what makes a panel look washed out.
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  /// Backdrop blur. Apple's panels sit around 20–30 at this size.
  final double blur;

  /// Strength of the glass tint. Higher = more opaque, more legible, less
  /// of the backdrop showing through.
  final double opacity;

  /// Optional colour pushed into the glass, for panels that should carry a
  /// hue rather than being neutral.
  final Color? tint;

  /// Elevation of the drop shadow.
  final double elevation;

  const LiquidGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.blur = 24,
    this.opacity = 1,
    this.tint,
    this.elevation = 1,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final border = BorderRadius.circular(radius);

    // Base tint. Light mode leans on white so text stays dark-on-light;
    // dark mode uses a lifted grey so the panel separates from the ground.
    final base = tint ?? (dark ? const Color(0xFF2A2D36) : Colors.white);
    final fill = base.withValues(
      alpha: (dark ? 0.55 : 0.62) * opacity,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: border,
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.55 * elevation)
                : const Color(0xFF16233F).withValues(alpha: 0.13 * elevation),
            blurRadius: 34 * elevation,
            offset: Offset(0, 14 * elevation),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: border,
        child: BackdropFilter(
          // Saturation is the half most implementations miss — without it the
          // backdrop greys out and the panel looks like frosted plastic.
          filter: ImageFilter.compose(
            outer: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            inner: ColorFilter.matrix(_saturate(1.7)),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: border,
              // Top-biased sheen: the specular catch that reads as glass.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.02),
                        Colors.transparent,
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.55),
                        Colors.white.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                stops: const [0, 0.42, 1],
              ),
            ),
            child: CustomPaint(
              // Painted rather than a Border so the rim can vary around the
              // edge — bright where light lands, dark where it falls away.
              foregroundPainter: _RimPainter(radius: radius, dark: dark),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }

  /// Saturation matrix. 1 = unchanged, >1 boosts colour.
  static List<double> _saturate(double s) {
    // Luminance coefficients (Rec. 601), the standard basis for this matrix.
    const lr = 0.213, lg = 0.715, lb = 0.072;
    final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
    return [
      sr + s, sg, sb, 0, 0,
      sr, sg + s, sb, 0, 0,
      sr, sg, sb + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}

/// Hairline rim that brightens toward the top and darkens toward the bottom.
class _RimPainter extends CustomPainter {
  final double radius;
  final bool dark;

  const _RimPainter({required this.radius, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? [
                Colors.white.withValues(alpha: 0.34),
                Colors.white.withValues(alpha: 0.08),
                Colors.black.withValues(alpha: 0.22),
              ]
            : [
                Colors.white.withValues(alpha: 0.95),
                Colors.white.withValues(alpha: 0.35),
                const Color(0xFF16233F).withValues(alpha: 0.10),
              ],
        stops: const [0, 0.5, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.radius != radius || old.dark != dark;
}
