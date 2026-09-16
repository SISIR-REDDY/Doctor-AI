import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/care_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';
import '../../theme/motion.dart';

/// Structured lab results: one row per marker with the value, the printed
/// reference range, a range bar showing where the value sits, and the change
/// since the user's previous reading of the same marker.
///
/// Colour comes only from the lab's own flag or the printed range — see
/// [LabMarker]. Markers without a range are listed plainly, never guessed.
class LabResultsView extends StatefulWidget {
  final List<LabMarker> markers;

  /// Previous readings keyed by [LabMarker.key], from [priorReadings].
  final Map<String, LabPrior> priors;

  const LabResultsView({super.key, required this.markers, this.priors = const {}});

  @override
  State<LabResultsView> createState() => _LabResultsViewState();
}

class _LabResultsViewState extends State<LabResultsView>
    with SingleTickerProviderStateMixin, SceneTimeline {
  @override
  Duration get sceneDuration => const Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    playScene();
  }

  @override
  Widget build(BuildContext context) {
    // Abnormal first — that is what the user opened the report to find out.
    final sorted = [...widget.markers]..sort((a, b) {
        int rank(LabStatus s) => switch (s) {
              LabStatus.high || LabStatus.low || LabStatus.abnormal => 0,
              LabStatus.normal => 1,
              LabStatus.unknown => 2,
            };
        return rank(a.status).compareTo(rank(b.status));
      });
    final flagged = sorted.where((m) => _isFlagged(m.status)).length;

    return InsetCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(CupertinoIcons.lab_flask_solid, color: AppTheme.infoColor, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Results',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: AppTheme.textPrimary)),
                    Text(
                      flagged == 0
                          ? '${sorted.length} markers · all within range'
                          : '${sorted.length} markers · $flagged outside range',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (flagged > 0)
                Pill('$flagged flagged', color: AppTheme.warningColor,
                    icon: CupertinoIcons.exclamationmark_circle_fill),
            ],
          ),
          Divider(height: 22, color: AppTheme.dividerColor),
          for (var i = 0; i < sorted.length; i++)
            FadeSlide(
              animation: scene,
              interval: Motion.stagger(i, step: 0.05, span: 0.4),
              dy: 0,
              dx: -12,
              child: _MarkerRow(
                marker: sorted[i],
                prior: widget.priors[sorted[i].key],
                animation: scene,
                grade: Motion.stagger(i, start: 0.25, step: 0.05, span: 0.35),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Ranges are the laboratory’s own. Flags are informational — discuss results with your clinician.',
            style: TextStyle(fontSize: 11, height: 1.35, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  static bool _isFlagged(LabStatus s) =>
      s == LabStatus.high || s == LabStatus.low || s == LabStatus.abnormal;
}

class _MarkerRow extends StatelessWidget {
  final LabMarker marker;
  final LabPrior? prior;
  final Animation<double> animation;
  final Interval grade;

  const _MarkerRow({
    required this.marker,
    required this.prior,
    required this.animation,
    required this.grade,
  });

  Color _statusColor(LabStatus s) => switch (s) {
        LabStatus.high || LabStatus.abnormal => AppTheme.dangerColor,
        LabStatus.low => AppTheme.warningColor,
        LabStatus.normal => AppTheme.successColor,
        LabStatus.unknown => AppTheme.textSecondary,
      };

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(v.abs() < 10 ? 2 : 1);

  @override
  Widget build(BuildContext context) {
    final m = marker;
    final target = _statusColor(m.status);
    final pos = m.position;
    final p = prior;
    final delta = p == null ? null : m.value - p.value;

    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final g = CurvedAnimation(parent: animation, curve: grade).value.clamp(0.0, 1.0);
        final c = Color.lerp(AppTheme.textTertiary, target, g)!;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  Text('${_fmt(m.value)}${m.unit.isEmpty ? '' : ' ${m.unit}'}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: c,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  if (m.refText.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(m.refText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w500,
                              color: AppTheme.textTertiary)),
                    ),
                  ],
                ],
              ),
              if (pos != null) ...[
                const SizedBox(height: 6),
                _RangeBar(position: pos, color: c, reveal: g, marker: m),
              ],
              if (delta != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      delta > 0
                          ? CupertinoIcons.arrow_up_right
                          : delta < 0
                              ? CupertinoIcons.arrow_down_right
                              : CupertinoIcons.minus,
                      size: 11,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        delta == 0
                            ? 'Unchanged from ${DateFormat.MMM().format(p!.date)}'
                            : '${delta > 0 ? '+' : ''}${_fmt(delta)} since ${DateFormat.MMM().format(p!.date)} (was ${_fmt(p.value)})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A track with the normal band marked; the value dot slides into place.
class _RangeBar extends StatelessWidget {
  final double position;
  final Color color;
  final double reveal;
  final LabMarker marker;

  const _RangeBar({
    required this.position,
    required this.color,
    required this.reveal,
    required this.marker,
  });

  @override
  Widget build(BuildContext context) {
    // The normal band occupies the middle of the padded track — same padding
    // as LabMarker.position (40% headroom either side).
    final hasLow = marker.refLow > 0;
    final hasHigh = marker.refHigh > 0;
    // Track = [low - 0.4span, high + 0.4span]; band = [low, high] → 0.222..0.778.
    const bandStart = 0.4 / 1.8;
    const bandEnd = 1.4 / 1.8;
    final bandLeft = hasLow ? bandStart : 0.0;
    final bandRight = hasHigh ? bandEnd : 1.0;

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: 12,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Track.
            Positioned(
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Normal band.
            Positioned(
              left: w * bandLeft,
              width: w * (bandRight - bandLeft),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Value dot — slides from the band's centre to its true spot.
            Positioned(
              left: (w * (0.5 + ((position - 0.5) * reveal))) - 6,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.surfaceColor, width: 2),
                  boxShadow: DS.softShadow(y: 1, blur: 4),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
