import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';
import '../../theme/motion.dart';

/// The animated art for the welcome slides.
///
/// Each scene *performs* the work Clinix does rather than describing it: the
/// bill is scanned line by line, overcharges are flagged as they are found, the
/// recovered total counts up. Scenes replay whenever their page becomes active,
/// so a user who swipes back sees the story again.
///
/// All scenes are pure presentation with hard-coded sample figures — they are
/// illustrations, not real audits. The numbers are deliberately modest and the
/// savings are always framed as "potential" (see APPSTORE_COMPLIANCE.md §5).

/// Base for a scene that replays when it becomes the visible page.
abstract class SceneWidget extends StatefulWidget {
  /// 0 = fully visible and active; grows as the page is swiped away.
  final double offset;
  final bool active;

  const SceneWidget({super.key, required this.offset, required this.active});
}

/// Shared parallax + card chrome for every scene.
class SceneFrame extends StatelessWidget {
  final double offset;
  final Widget child;
  final Gradient? gradient;
  final EdgeInsets padding;

  const SceneFrame({
    super.key,
    required this.offset,
    required this.child,
    this.gradient,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    // Cards drift slightly slower than the page, which reads as depth.
    final parallax = offset * -46;
    final fade = (1 - offset.abs().clamp(0.0, 1.0) * 0.75).clamp(0.0, 1.0);

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppTheme.surfaceColor : null,
        borderRadius: DS.squircle(DS.rXl),
        border: Border.all(color: AppTheme.glassBorder, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B2A4A)
                .withValues(alpha: AppTheme.isDark ? 0.5 : 0.14),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );

    return LayoutBuilder(builder: (context, c) {
      // FittedBox gives its child unbounded width, so pin the card to the
      // slot's width first; only the height is then free to scale down.
      final width =
          c.maxWidth.isFinite ? c.maxWidth.clamp(0.0, 360.0) : 360.0;
      return FittedBox(
        // On a small phone at large accessibility text the card's natural
        // height exceeds its slot. Scaling down beats clipping or overflowing:
        // the text still honours the user's size wherever it has room.
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: width.toDouble(),
          child: Transform.translate(
            offset: Offset(parallax, 0),
            child: Opacity(opacity: fade, child: card),
          ),
        ),
      );
    });
  }
}

// ── Scene 1 · the bill is read and audited ───────────────────────────────────

class BillScene extends SceneWidget {
  const BillScene({super.key, required super.offset, required super.active});

  @override
  State<BillScene> createState() => _BillSceneState();
}

class _BillSceneState extends State<BillScene>
    with SingleTickerProviderStateMixin, SceneTimeline {
  @override
  Duration get sceneDuration => const Duration(milliseconds: 3200);

  @override
  void initState() {
    super.initState();
    if (widget.active) playScene();
  }

  @override
  void didUpdateWidget(BillScene old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) playScene();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    return SceneFrame(
      offset: widget.offset,
      child: ScanSweep(
        animation: scene,
        // The beam sweeps first — the document is being read.
        interval: const Interval(0.02, 0.34, curve: Curves.easeInOut),
        color: AppTheme.primaryColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeSlide(
              animation: scene,
              interval: const Interval(0, 0.18, curve: Motion.enter),
              dy: 8,
              child: Row(
                children: [
                  IconBadge(CupertinoIcons.doc_text_fill,
                      color: AppTheme.primaryColor, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Riverside Medical Center',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.textPrimary)),
                        _ReadingLabel(animation: scene),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 22, color: AppTheme.dividerColor),
            // Lines resolve in sequence; the two problems flag after the
            // beam has passed over them.
            _BillLine(
              animation: scene,
              appear: const Interval(0.20, 0.40, curve: Motion.enter),
              label: 'Office visit, level 4',
              amount: r'$389',
            ),
            _BillLine(
              animation: scene,
              appear: const Interval(0.26, 0.46, curve: Motion.enter),
              flagAt: const Interval(0.56, 0.78, curve: Motion.spring),
              label: 'CBC with differential',
              amount: r'$92',
              tag: 'Duplicate',
            ),
            _BillLine(
              animation: scene,
              appear: const Interval(0.32, 0.52, curve: Motion.enter),
              flagAt: const Interval(0.66, 0.88, curve: Motion.spring),
              label: 'CT head w/o contrast',
              amount: r'$1,850',
              tag: '5.9× rate',
            ),
            _BillLine(
              animation: scene,
              appear: const Interval(0.38, 0.58, curve: Motion.enter),
              label: 'Venipuncture',
              amount: r'$18',
            ),
            const SizedBox(height: 12),
            FadeSlide(
              animation: scene,
              interval: const Interval(0.78, 1.0, curve: Motion.springHeavy),
              dy: 12,
              from: 0.94,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor
                      .withValues(alpha: dark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.successColor.withValues(alpha: 0.35),
                      width: 0.9),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.sparkles,
                        size: 18, color: AppTheme.successColor),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('2 problems found',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.successColor
                                      .withValues(alpha: 0.9))),
                          const SizedBox(height: 1),
                          // Amount and qualifier stack so neither has to
                          // fit on one line on a narrow phone.
                          CountUp(
                            animation: scene,
                            interval: const Interval(0.78, 1, curve: Motion.enter),
                            value: 1610,
                            prefix: r'$',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                height: 1.1,
                                color: AppTheme.successColor),
                          ),
                          Text('you can dispute',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.successColor
                                      .withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Reading…" that resolves into the line count once the sweep finishes.
class _ReadingLabel extends StatelessWidget {
  final Animation<double> animation;
  const _ReadingLabel({required this.animation});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 11.5, color: AppTheme.textSecondary);
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final done = animation.value > 0.36;
        return AnimatedSwitcher(
          duration: Motion.fast,
          child: done
              ? Text('Itemized statement · 4 lines',
                  key: const ValueKey('done'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style)
              : Row(
                  key: const ValueKey('reading'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 9,
                      height: 9,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.6, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 6),
                    // Ellipsise on narrow phones: during the AnimatedSwitcher
                    // crossfade both labels are laid out at once.
                    Flexible(
                      child: Text('Reading every line…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// One bill row. Neutral on arrival, then turns red when its flag lands.
class _BillLine extends StatelessWidget {
  final Animation<double> animation;
  final Interval appear;
  final Interval? flagAt;
  final String label;
  final String amount;
  final String? tag;

  const _BillLine({
    required this.animation,
    required this.appear,
    required this.label,
    required this.amount,
    this.flagAt,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final flag = flagAt;
    return FadeSlide(
      animation: animation,
      interval: appear,
      dy: 0,
      dx: -18,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) {
          final f = flag == null
              ? 0.0
              : CurvedAnimation(parent: animation, curve: flag).value;
          final flagged = f > 0.01;
          final dot = Color.lerp(
              AppTheme.successColor, AppTheme.dangerColor, f.clamp(0.0, 1.0))!;
          final amountColor = Color.lerp(
              AppTheme.textPrimary, AppTheme.dangerColor, f.clamp(0.0, 1.0))!;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                // Label + flag share the flexible middle so a long tag
                // ellipsises the label instead of overflowing the card.
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                      ),
                      if (flagged && tag != null) ...[
                        const SizedBox(width: 8),
                        // Flexible so the pill ellipsises with the row instead
                        // of forcing it wider; the scale overshoot is a paint
                        // transform and never affects layout width.
                        Flexible(
                          child: Opacity(
                            opacity: f.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: (0.7 + (0.3 * f)).clamp(0.0, 1.2),
                              child: Pill(tag!, color: AppTheme.dangerColor),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(amount,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: amountColor,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Scene 2 · the denial becomes an appeal ───────────────────────────────────

class DenialScene extends SceneWidget {
  const DenialScene({super.key, required super.offset, required super.active});

  @override
  State<DenialScene> createState() => _DenialSceneState();
}

class _DenialSceneState extends State<DenialScene>
    with SingleTickerProviderStateMixin, SceneTimeline {
  @override
  Duration get sceneDuration => const Duration(milliseconds: 3000);

  @override
  void initState() {
    super.initState();
    if (widget.active) playScene();
  }

  @override
  void didUpdateWidget(DenialScene old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) playScene();
  }

  @override
  Widget build(BuildContext context) {
    return SceneFrame(
      offset: widget.offset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeSlide(
            animation: scene,
            interval: const Interval(0, 0.16, curve: Motion.enter),
            dy: 8,
            child: Row(
              children: [
                IconBadge(CupertinoIcons.envelope_fill,
                    color: AppTheme.dangerColor, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Claim denied — MRI lumbar spine',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.textPrimary)),
                      Text('“Not medically necessary”',
                          style: TextStyle(
                              fontSize: 11.5, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Each step ticks off in turn — the work happening, not a list.
          _TickStep(
            animation: scene,
            interval: const Interval(0.20, 0.40, curve: Motion.spring),
            text: 'Denial reason decoded in plain English',
          ),
          _TickStep(
            animation: scene,
            interval: const Interval(0.34, 0.54, curve: Motion.spring),
            text: 'Your appeal rights under state law found',
          ),
          _TickStep(
            animation: scene,
            interval: const Interval(0.48, 0.68, curve: Motion.spring),
            text: 'Appeal drafted, citing your own policy',
          ),
          _TickStep(
            animation: scene,
            interval: const Interval(0.62, 0.82, curve: Motion.spring),
            text: 'Deadline set — 172 days to file',
            accent: AppTheme.warningColor,
            icon: CupertinoIcons.bell_fill,
          ),
          const SizedBox(height: 14),
          FadeSlide(
            animation: scene,
            interval: const Interval(0.80, 1, curve: Motion.spring),
            dy: 10,
            from: 0.92,
            // Wraps rather than overflowing when the type scale is large.
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill('Appeal ready to send',
                    color: AppTheme.successColor,
                    icon: CupertinoIcons.checkmark_seal_fill),
                Pill('You send it, not us',
                    color: AppTheme.primaryColor,
                    icon: CupertinoIcons.hand_raised_fill),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A checklist row whose tick draws itself when its interval arrives.
class _TickStep extends StatelessWidget {
  final Animation<double> animation;
  final Interval interval;
  final String text;
  final Color? accent;
  final IconData icon;

  const _TickStep({
    required this.animation,
    required this.interval,
    required this.text,
    this.accent,
    this.icon = CupertinoIcons.checkmark_circle_fill,
  });

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppTheme.successColor;
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final v = CurvedAnimation(parent: animation, curve: interval).value;
        final done = v.clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.5),
          child: Row(
            children: [
              // Ring fills, then the tick pops in — reads as "working… done".
              SizedBox(
                width: 20,
                height: 20,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RingProgress(
                      animation: animation,
                      interval: Interval(interval.begin,
                          interval.begin + ((interval.end - interval.begin) * 0.7),
                          curve: Curves.easeOut),
                      size: 20,
                      stroke: 2,
                      color: c,
                      track: AppTheme.textTertiary.withValues(alpha: 0.25),
                    ),
                    Transform.scale(
                      scale: done,
                      child: Icon(icon, size: 20, color: c),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Opacity(
                  opacity: (0.35 + (0.65 * done)).clamp(0.0, 1.0),
                  child: Text(text,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Scene 3 · the money comes back ───────────────────────────────────────────

class MoneyScene extends SceneWidget {
  const MoneyScene({super.key, required super.offset, required super.active});

  @override
  State<MoneyScene> createState() => _MoneySceneState();
}

class _MoneySceneState extends State<MoneyScene>
    with SingleTickerProviderStateMixin, SceneTimeline {
  @override
  Duration get sceneDuration => const Duration(milliseconds: 2800);

  @override
  void initState() {
    super.initState();
    if (widget.active) playScene();
  }

  @override
  void didUpdateWidget(MoneyScene old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) playScene();
  }

  @override
  Widget build(BuildContext context) {
    return SceneFrame(
      offset: widget.offset,
      gradient: AppTheme.primaryGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeSlide(
            animation: scene,
            interval: const Interval(0, 0.2, curve: Motion.enter),
            dy: 8,
            child: Text('Recovered so far',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: Colors.white.withValues(alpha: 0.85))),
          ),
          const SizedBox(height: 2),
          // The hero number counts up — the payoff of the whole flow.
          CountUp(
            animation: scene,
            interval: const Interval(0.12, 0.66, curve: Curves.easeOutCubic),
            value: 2340,
            prefix: r'$',
            style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.6,
                height: 1.05,
                color: Colors.white),
          ),
          const SizedBox(height: 14),
          _MoneyBar(animation: scene),
          const SizedBox(height: 16),
          FadeSlide(
            animation: scene,
            interval: const Interval(0.72, 0.94, curve: Motion.enter),
            dy: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.lock_shield_fill,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your documents stay private. Never sold, never used to train anyone’s AI.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Split bar: recovered vs still in dispute, each half growing into place.
class _MoneyBar extends StatelessWidget {
  final Animation<double> animation;
  const _MoneyBar({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: AnimatedBuilder(
              animation: animation,
              builder: (_, __) {
                final grow = CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
                ).value.clamp(0.0, 1.0);
                return Row(
                  children: [
                    Expanded(
                      flex: (2340 * grow).round().clamp(1, 100000),
                      child: Container(color: Colors.white),
                    ),
                    Expanded(
                      flex: (1610 * grow).round().clamp(1, 100000),
                      child: Container(
                          color: Colors.white.withValues(alpha: 0.32)),
                    ),
                    if (grow < 1)
                      Expanded(
                        flex: ((3950 * (1 - grow))).round().clamp(1, 100000),
                        child: Container(
                            color: Colors.white.withValues(alpha: 0.12)),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Legend(
                animation: animation,
                interval: const Interval(0.56, 0.78, curve: Motion.enter),
                swatch: Colors.white,
                label: 'Paid back',
                value: r'$2,340',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Legend(
                animation: animation,
                interval: const Interval(0.62, 0.84, curve: Motion.enter),
                swatch: Colors.white.withValues(alpha: 0.32),
                label: 'In dispute',
                value: r'$1,610',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Animation<double> animation;
  final Interval interval;
  final Color swatch;
  final String label;
  final String value;

  const _Legend({
    required this.animation,
    required this.interval,
    required this.swatch,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return FadeSlide(
      animation: animation,
      interval: interval,
      dy: 8,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration:
                BoxDecoration(color: swatch, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8))),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
