import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class WorkflowHeaderStat {
  final IconData icon;
  final String label;

  const WorkflowHeaderStat({
    required this.icon,
    required this.label,
  });
}

class WorkflowHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<WorkflowHeaderStat> stats;
  final Widget? trailing;
  final String? helperText;

  const WorkflowHeaderCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.stats = const [],
    this.trailing,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final endColor = Color.lerp(accentColor, Colors.black, 0.18) ?? accentColor;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.headingSmall.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppTheme.sm),
                  trailing!,
                ],
              ],
            ),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: AppTheme.md),
              Wrap(
                spacing: AppTheme.sm,
                runSpacing: AppTheme.sm,
                children: stats.map(_buildStatPill).toList(),
              ),
            ],
            if (helperText != null && helperText!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.sm),
              Text(
                helperText!,
                style: AppTheme.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(WorkflowHeaderStat stat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: AppTheme.xs),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stat.icon, size: 14, color: Colors.white),
          const SizedBox(width: AppTheme.xs),
          Text(
            stat.label,
            style: AppTheme.labelSmall.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
