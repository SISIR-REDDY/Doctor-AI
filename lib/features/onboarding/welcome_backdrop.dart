import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Living backdrop for the welcome flow.
///
/// Two large colour orbs drift behind a heavy blur and shift hue as the user
/// pages through, so the background belongs to the current slide instead of
/// sitting behind it as a flat gradient. Everything is painted — no images,
/// no per-frame layout — so it stays cheap on older devices.
class WelcomeBackdrop extends StatefulWidget {
  /// Continuous page position from the PageView.
  final double scroll;

  /// Accent per page; the backdrop interpolates between neighbours.
  final List<Color> accents;

  const WelcomeBackdrop({super.key, required this.scroll, required this.accents});

  @override
  State<WelcomeBackdrop> createState() => _WelcomeBackdropState();
}

class _WelcomeBackdropState extends State<WelcomeBackdrop>
    with SingleTickerProviderStateMixin {
  // Slow, unsynced drift so the orbs never appear to loop in step.
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: const Duration(seconds: 22))
        ..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  Color _accentAt(double p) {
    final list = widget.accents;
    if (list.isEmpty) return AppTheme.primaryColor;
    final clamped = p.clamp(0.0, (list.length - 1).toDouble());
    final i = clamped.floor();
    final j = math.min(i + 1, list.length - 1);
    return Color.lerp(list[i], list[j], clamped - i) ?? list[i];
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final accent = _accentAt(widget.scroll);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _drift,
        builder: (_, __) {
          final t = _drift.value * math.pi * 2;
          return Stack(
            children: [
              // Base wash — keeps contrast predictable behind the orbs.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: dark
                          ? const [Color(0xFF0D1220), Color(0xFF0A0A0E)]
                          : const [Color(0xFFEAF1FF), Color(0xFFF7F9FD)],
                    ),
                  ),
                ),
              ),
              _Orb(
                alignment: Alignment(
                  -0.75 + math.sin(t) * 0.22 - (widget.scroll * 0.35),
                  -0.68 + math.cos(t * 0.8) * 0.16,
                ),
                size: 0.95,
                color: accent.withValues(alpha: dark ? 0.45 : 0.40),
              ),
              _Orb(
                alignment: Alignment(
                  0.85 + math.cos(t * 1.15) * 0.2 - (widget.scroll * 0.5),
                  0.12 + math.sin(t * 0.9) * 0.2,
                ),
                size: 0.78,
                color: Color.lerp(accent, AppTheme.secondaryColor, 0.55)!
                    .withValues(alpha: dark ? 0.34 : 0.28),
              ),
              // One blur pass over both orbs is far cheaper than blurring each.
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                  child: const SizedBox.expand(),
                ),
              ),
              // Settles the colour so text keeps its contrast ratio.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: dark
                          ? [
                              const Color(0xFF0A0A0E).withValues(alpha: 0.10),
                              const Color(0xFF0A0A0E).withValues(alpha: 0.72),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0.80),
                            ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;

  const _Orb({required this.alignment, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: size,
        heightFactor: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented progress rail that fills continuously with the page scroll.
///
/// Replaces dots: it reads as "3 chapters, you are partway through the
/// second" rather than as an anonymous position indicator.
class ProgressRail extends StatelessWidget {
  final int count;
  final double scroll;
  final Color color;

  const ProgressRail({
    super.key,
    required this.count,
    required this.scroll,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        // Each segment fills 0→1 as the scroll passes through its index.
        final fill = (scroll - i + 1).clamp(0.0, 1.0);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: fill,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
