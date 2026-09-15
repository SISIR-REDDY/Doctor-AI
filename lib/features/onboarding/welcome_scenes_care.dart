import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../theme/motion.dart';
import 'welcome_scenes.dart';

/// Scenes for the care side of Clinix: reports decoded, the AI assistant,
/// and the vault. Same rules as the money scenes — each performs the work
/// with sample data, and nothing here claims to diagnose or treat.

// ── Report decoded ───────────────────────────────────────────────────────────

class ReportScene extends SceneWidget {
  const ReportScene({super.key, required super.offset, required super.active});

  @override
  State<ReportScene> createState() => _ReportSceneState();
}

class _ReportSceneState extends State<ReportScene>
    with SingleTickerProviderStateMixin, SceneTimeline {
  @override
  Duration get sceneDuration => const Duration(milliseconds: 3200);

  @override
  void initState() {
    super.initState();
    if (widget.active) playScene();
  }

  @override
  void didUpdateWidget(ReportScene old) {
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
        interval: const Interval(0.02, 0.32, curve: Curves.easeInOut),
        color: AppTheme.infoColor,
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
                  IconBadge(CupertinoIcons.lab_flask_solid,
                      color: AppTheme.infoColor, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Blood panel · 14 Sep',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                letterSpacing: -0.2,
                                color: AppTheme.textPrimary)),
                        Text('Quest Diagnostics · 12 markers',
                            style: TextStyle(
                                fontSize: 11.5, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 22, color: AppTheme.dividerColor),
            _LabRow(
              animation: scene,
              appear: const Interval(0.18, 0.38, curve: Motion.enter),
              grade: const Interval(0.44, 0.60, curve: Motion.spring),
              name: 'HbA1c',
              value: '5.4 %',
              range: '< 5.7',
              color: AppTheme.successColor,
              fill: 0.42,
            ),
            _LabRow(
              animation: scene,
              appear: const Interval(0.24, 0.44, curve: Motion.enter),
              grade: const Interval(0.52, 0.68, curve: Motion.spring),
              name: 'LDL cholesterol',
              value: '148 mg/dL',
              range: '< 100',
              color: AppTheme.warningColor,
              fill: 0.78,
            ),
            _LabRow(
              animation: scene,
              appear: const Interval(0.30, 0.50, curve: Motion.enter),
              grade: const Interval(0.60, 0.76, curve: Motion.spring),
              name: 'Vitamin D',
              value: '19 ng/mL',
              range: '30 – 100',
              color: AppTheme.dangerColor,
              fill: 0.22,
            ),
            const SizedBox(height: 12),
            FadeSlide(
              animation: scene,
              interval: const Interval(0.78, 1.0, curve: Motion.springHeavy),
              dy: 12,
              from: 0.94,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withValues(alpha: dark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.infoColor.withValues(alpha: 0.3), width: 0.9),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(CupertinoIcons.text_bubble_fill,
                        size: 16, color: AppTheme.infoColor),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'In plain English: blood sugar is fine. Cholesterol is high and vitamin D is low — two things worth raising at your next visit.',
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary),
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

/// A lab marker whose range bar fills and whose status colour lands after
/// the sweep has read it.
class _LabRow extends StatelessWidget {
  final Animation<double> animation;
  final Interval appear;
  final Interval grade;
  final String name;
  final String value;
  final String range;
  final Color color;

  /// Where the value sits on the range bar, 0–1.
  final double fill;

  const _LabRow({
    required this.animation,
    required this.appear,
    required this.grade,
    required this.name,
    required this.value,
    required this.range,
    required this.color,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return FadeSlide(
      animation: animation,
      interval: appear,
      dy: 0,
      dx: -18,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) {
          final g = CurvedAnimation(parent: animation, curve: grade)
              .value
              .clamp(0.0, 1.0);
          final c = Color.lerp(AppTheme.textTertiary, color, g)!;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                    ),
                    Text(value,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: c,
                            fontFeatures: const [FontFeature.tabularFigures()])),
                    const SizedBox(width: 6),
                    // The reference range is the least important figure on
                    // the row; it truncates first on narrow phones.
                    Flexible(
                      child: Text(range,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textTertiary)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                              color: AppTheme.textTertiary.withValues(alpha: 0.18)),
                        ),
                        FractionallySizedBox(
                          widthFactor: (fill * g).clamp(0.0, 1.0),
                          heightFactor: 1,
                          alignment: Alignment.centerLeft,
                          child: ColoredBox(color: c),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── AI assistant ─────────────────────────────────────────────────────────────

class AssistantScene extends SceneWidget {
  const AssistantScene({super.key, required super.offset, required super.active});

  @override
  State<AssistantScene> createState() => _AssistantSceneState();
}

class _AssistantSceneState extends State<AssistantScene>
    with SingleTickerProviderStateMixin, SceneTimeline {
  @override
  Duration get sceneDuration => const Duration(milliseconds: 3400);

  @override
  void initState() {
    super.initState();
    if (widget.active) playScene();
  }

  @override
  void didUpdateWidget(AssistantScene old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) playScene();
  }

  @override
  Widget build(BuildContext context) {
    return SceneFrame(
      offset: widget.offset,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Bubble(
            animation: scene,
            interval: const Interval(0.0, 0.2, curve: Motion.spring),
            mine: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.mic_fill, size: 13,
                    color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'My LDL came back at 148 — should I worry?',
                    style: TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.3,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _Typing(animation: scene, interval: const Interval(0.22, 0.44)),
          _Bubble(
            animation: scene,
            interval: const Interval(0.44, 0.66, curve: Motion.spring),
            mine: false,
            child: Text(
              '148 is above the usual target of 100, but not an emergency. Your panel from March was 131, so it has risen. Diet and activity move this most; a doctor may discuss a statin if it stays high.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.38, fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlide(
            animation: scene,
            interval: const Interval(0.72, 0.92, curve: Motion.enter),
            dy: 8,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pill('Read from your March panel',
                    color: AppTheme.infoColor, icon: CupertinoIcons.doc_text_fill),
                Pill('Not a diagnosis',
                    color: AppTheme.textSecondary, icon: CupertinoIcons.info),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Animation<double> animation;
  final Interval interval;
  final bool mine;
  final Widget child;
  const _Bubble({
    required this.animation,
    required this.interval,
    required this.mine,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    return FadeSlide(
      animation: animation,
      interval: interval,
      dy: 10,
      dx: mine ? 14 : -14,
      from: 0.92,
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 290),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              gradient: mine ? AppTheme.primaryGradient : null,
              color: mine
                  ? null
                  : (dark ? const Color(0xFF2A2D36) : const Color(0xFFF1F4FA)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 6),
                bottomRight: Radius.circular(mine ? 6 : 18),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Three dots that pulse while the reply is "thinking", then leave.
class _Typing extends StatelessWidget {
  final Animation<double> animation;
  final Interval interval;
  const _Typing({required this.animation, required this.interval});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = animation.value;
        if (t < interval.begin || t > interval.end) return const SizedBox.shrink();
        final local = (t - interval.begin) / (interval.end - interval.begin);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase = ((local * 3) - (i * 0.33)) % 1;
                final up = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.textTertiary.withValues(alpha: 0.35 + (0.55 * up)),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

// ── Vault ────────────────────────────────────────────────────────────────────

class VaultScene extends SceneWidget {
  const VaultScene({super.key, required super.offset, required super.active});

  @override
  State<VaultScene> createState() => _VaultSceneState();
}

class _VaultSceneState extends State<VaultScene>
    with SingleTickerProviderStateMixin, SceneTimeline {
  @override
  Duration get sceneDuration => const Duration(milliseconds: 3000);

  @override
  void initState() {
    super.initState();
    if (widget.active) playScene();
  }

  @override
  void didUpdateWidget(VaultScene old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) playScene();
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <(IconData, Color, String, String)>[
      (CupertinoIcons.doc_text_fill, AppTheme.primaryColor, 'Records', '23 files'),
      (CupertinoIcons.capsule_fill, AppTheme.oncologyColor, 'Medications', '3 active'),
      (CupertinoIcons.lab_flask_solid, AppTheme.infoColor, 'Lab results', '6 panels'),
      (CupertinoIcons.person_2_fill, AppTheme.successColor, 'Family', 'Mum · Leo'),
    ];
    return SceneFrame(
      offset: widget.offset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            // Roomy enough for two lines of type on a 320pt phone.
            childAspectRatio: 1.85,
            children: [
              for (var i = 0; i < tiles.length; i++)
                FadeSlide(
                  animation: scene,
                  interval: Motion.stagger(i, start: 0.04, step: 0.1, span: 0.4),
                  dy: 10,
                  from: 0.9,
                  child: _VaultTile(
                    icon: tiles[i].$1,
                    color: tiles[i].$2,
                    label: tiles[i].$3,
                    meta: tiles[i].$4,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // The reminder firing is the moment that shows the vault working
          // for you rather than sitting there.
          FadeSlide(
            animation: scene,
            interval: const Interval(0.58, 0.82, curve: Motion.spring),
            dy: 14,
            from: 0.94,
            child: _ReminderRow(animation: scene),
          ),
        ],
      ),
    );
  }
}

class _VaultTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String meta;
  const _VaultTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2D36) : const Color(0xFFF1F4FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconBadge(icon, color: color, size: 30),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final Animation<double> animation;
  const _ReminderRow({required this.animation});

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.oncologyColor.withValues(alpha: dark ? 0.2 : 0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.oncologyColor.withValues(alpha: 0.32), width: 0.9),
      ),
      child: Row(
        children: [
          // The tick draws after the row lands.
          AnimatedBuilder(
            animation: animation,
            builder: (_, __) {
              final v = CurvedAnimation(
                parent: animation,
                curve: const Interval(0.84, 1.0, curve: Motion.spring),
              ).value.clamp(0.0, 1.0);
              return SizedBox(
                width: 22,
                height: 22,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(CupertinoIcons.bell_fill, size: 20,
                        color: AppTheme.oncologyColor.withValues(alpha: 1 - v)),
                    Transform.scale(
                      scale: v,
                      child: Icon(CupertinoIcons.checkmark_circle_fill,
                          size: 22, color: AppTheme.successColor),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Metformin 500 mg · 8:00 pm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Text('Taken — 41-day streak',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
