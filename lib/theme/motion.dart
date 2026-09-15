import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_animations.dart' show kReduceMotion;

/// Shared motion vocabulary for Clinix.
///
/// Onboarding and result screens tell a story — a document is read, lines are
/// checked, money is found. These primitives keep that story consistent: the
/// same curves, the same stagger rhythm, the same entrance everywhere.
class Motion {
  Motion._();

  /// iOS-like decelerate. Fast out of the gate, long soft landing.
  static const Curve enter = Curves.easeOutCubic;

  /// Slight overshoot for things that "land" (flags, badges, checkmarks).
  static const Curve settle = Curves.easeOutBack;

  /// Critically-damped spring: fast approach, one small overshoot, no ringing.
  /// Use where something should feel physical rather than tweened — a flag
  /// snapping onto a row, a card arriving.
  static const Curve spring = _Spring(damping: 0.62, frequency: 2.4);

  /// A heavier spring for large objects (whole cards, sheets).
  static const Curve springHeavy = _Spring(damping: 0.78, frequency: 1.6);

  /// Symmetric, for crossfades and colour shifts.
  static const Curve shift = Curves.easeInOut;

  static const Duration fast = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 420);
  static const Duration slow = Duration(milliseconds: 700);

  /// Interval for item [i] of a staggered list inside a 0→1 parent timeline.
  ///
  /// [start] is where the first item begins, [step] the gap between items and
  /// [span] how long each item takes. Clamped so a long list never exceeds 1.
  static Interval stagger(int i, {double start = 0, double step = 0.09, double span = 0.55}) {
    final begin = math.min(start + (i * step), 0.999);
    final end = math.min(begin + span, 1.0);
    return Interval(begin, end, curve: enter);
  }
}

/// Damped-spring curve.
///
/// Flutter's easeOutBack overshoots on a fixed schedule, which looks the same
/// on every element and reads as "tweened". A spring's overshoot decays, so
/// heavier things settle differently from lighter ones.
class _Spring extends Curve {
  /// 0 = undamped (rings forever), 1 = critically damped (no overshoot).
  final double damping;

  /// Oscillations over the curve's duration. Higher = snappier.
  final double frequency;

  const _Spring({required this.damping, required this.frequency});

  @override
  double transformInternal(double t) {
    final w = frequency * 2 * math.pi;
    final decay = math.exp(-damping * w * t);
    // Damped sinusoid approaching 1 from below, then settling onto it.
    final wd = w * math.sqrt(math.max(1 - (damping * damping), 0.0001));
    return 1 - decay * (math.cos(wd * t) + (damping * w / wd) * math.sin(wd * t));
  }
}

/// Drives a scene's 0→1 timeline, replaying it whenever the scene becomes
/// active (e.g. its onboarding page scrolls into view).
///
/// Honours reduce-motion: the timeline jumps straight to 1, so every
/// [FadeSlide], [CountUp] and flag shows its final state with no movement.
mixin SceneTimeline<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  AnimationController? _scene;

  /// The scene's timeline. Created on first use.
  ///
  /// Deliberately not `late final`: a PageView can build a page and discard it
  /// before the scene ever plays, and a `late final` initialiser would then run
  /// inside dispose(), constructing an AnimationController against a
  /// deactivated element (TickerMode lookup throws).
  AnimationController get scene =>
      _scene ??= AnimationController(vsync: this, duration: sceneDuration);

  /// Total length of the scene's story. Override per scene.
  Duration get sceneDuration => const Duration(milliseconds: 2600);

  /// Restarts the story from the top.
  void playScene() {
    if (kReduceMotion) {
      scene.value = 1;
      return;
    }
    scene.forward(from: 0);
  }

  @override
  void dispose() {
    _scene?.dispose();
    super.dispose();
  }
}

/// Fades and lifts [child] into place along a 0→1 [animation] within [interval].
///
/// The workhorse for staggered content: every row, pill and line in the
/// onboarding art uses it so everything shares one entrance.
class FadeSlide extends StatelessWidget {
  final Animation<double> animation;
  final Interval interval;
  final Widget child;

  /// Vertical travel in logical pixels. Negative lifts from below.
  final double dy;

  /// Horizontal travel — used for things that slide in from an edge.
  final double dx;

  /// Scale to grow from. 1 disables the scale component.
  final double from;

  const FadeSlide({
    super.key,
    required this.animation,
    required this.interval,
    required this.child,
    this.dy = 14,
    this.dx = 0,
    this.from = 1,
  });

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: animation, curve: interval);
    return AnimatedBuilder(
      animation: t,
      child: child,
      builder: (_, c) {
        final v = t.value;
        return Opacity(
          // Fade in over the first 60% so movement finishes after the fade —
          // it reads as arriving, not as sliding while invisible. Spring
          // curves overshoot past 1, so clamp before transforming.
          opacity: Curves.easeOut.transform((v * 1.6).clamp(0.0, 1.0)),
          child: Transform.translate(
            offset: Offset(dx * (1 - v), dy * (1 - v)),
            child: from == 1 ? c : Transform.scale(scale: from + ((1 - from) * v), child: c),
          ),
        );
      },
    );
  }
}

/// Counts from 0 to [value] with tabular digits so the width never jitters.
class CountUp extends StatelessWidget {
  final Animation<double> animation;
  final Interval interval;
  final double value;
  final TextStyle style;
  final String prefix;
  final String suffix;

  /// Formats the interpolated number. Defaults to a thousands-separated int.
  final String Function(double)? format;

  const CountUp({
    super.key,
    required this.animation,
    required this.interval,
    required this.value,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.format,
  });

  static String money(double v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: animation, curve: interval);
    return AnimatedBuilder(
      animation: t,
      builder: (_, __) {
        final v = value * t.value;
        return Text(
          '$prefix${(format ?? money)(v)}$suffix',
          style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        );
      },
    );
  }
}

/// A scanning light that sweeps down its child once, as a document is read.
///
/// Purely decorative overlay — it never intercepts pointers.
class ScanSweep extends StatelessWidget {
  final Animation<double> animation;
  final Interval interval;
  final Color color;
  final Widget child;

  const ScanSweep({
    super.key,
    required this.animation,
    required this.interval,
    required this.child,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: animation, curve: interval);
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: t,
              builder: (_, __) {
                final v = t.value;
                if (v <= 0 || v >= 1) return const SizedBox.shrink();
                // Fade the beam out at both ends so it appears and leaves
                // softly rather than popping at the card edges.
                final edge = math.min(v, 1 - v) * 4;
                return Opacity(
                  opacity: math.min(edge, 1.0),
                  child: FractionallySizedBox(
                    alignment: Alignment.topCenter,
                    heightFactor: 0.34,
                    widthFactor: 1,
                    child: Align(
                      alignment: Alignment(0, (v * 2.6) - 1.3),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color.withValues(alpha: 0),
                              color.withValues(alpha: 0.26),
                              color.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws a progress ring that fills as the timeline advances.
class RingProgress extends StatelessWidget {
  final Animation<double> animation;
  final Interval interval;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? center;

  const RingProgress({
    super.key,
    required this.animation,
    required this.interval,
    required this.color,
    required this.track,
    this.size = 64,
    this.stroke = 6,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: animation, curve: interval);
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: t,
        builder: (_, __) => CustomPaint(
          painter: _RingPainter(t.value, color, track, stroke),
          child: center == null ? null : Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  _RingPainter(this.progress, this.color, this.track, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, radius, base);
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      base..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

/// Gentle continuous float, for hero art that should feel alive at rest.
class Floating extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;

  const Floating({
    super.key,
    required this.child,
    this.amplitude = 5,
    this.period = const Duration(seconds: 5),
  });

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    // Started here rather than in a field initialiser so the controller always
    // exists by dispose() — see the note on SceneTimeline.scene.
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, c) => Transform.translate(
        offset: Offset(0, math.sin(_c.value * math.pi * 2) * widget.amplitude),
        child: c,
      ),
    );
  }
}
