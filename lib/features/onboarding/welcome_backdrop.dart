import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Backdrop for the welcome flow: clean white (or true black), with a faint
/// accent wash at the top that follows the current slide's colour.
///
/// Deliberately restrained. The content — the cards and the copy — carries
/// the screen; the background only hints which chapter you are in.
class WelcomeBackdrop extends StatelessWidget {
  /// Continuous page position from the PageView.
  final double scroll;

  /// Accent per page; the wash interpolates between neighbours.
  final List<Color> accents;

  const WelcomeBackdrop({super.key, required this.scroll, required this.accents});

  Color _accentAt(double p) {
    if (accents.isEmpty) return AppTheme.primaryColor;
    final clamped = p.clamp(0.0, (accents.length - 1).toDouble());
    final i = clamped.floor();
    final j = math.min(i + 1, accents.length - 1);
    return Color.lerp(accents[i], accents[j], clamped - i) ?? accents[i];
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final accent = _accentAt(scroll);
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(color: dark ? Colors.black : Colors.white),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -1.15),
              radius: 1.15,
              colors: [
                accent.withValues(alpha: dark ? 0.22 : 0.10),
                accent.withValues(alpha: 0),
              ],
            ),
          ),
          child: const SizedBox.expand(),
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
                  // heightFactor is required: without it the fill box has
                  // no intrinsic height and paints nothing.
                  FractionallySizedBox(
                    widthFactor: fill,
                    heightFactor: 1,
                    alignment: Alignment.centerLeft,
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
