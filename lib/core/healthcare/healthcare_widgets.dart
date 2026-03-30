import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class HealthcareEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const HealthcareEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: AppTheme.md),
            Text(title, style: AppTheme.headingSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.sm),
            Text(description, style: AppTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class HealthcareResultSheet {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
    Color? accentColor,
  }) {
    final color = accentColor ?? AppTheme.primaryColor;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(width: 10),
                    Expanded(child: Text(title, style: AppTheme.headingSmall)),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      content.trim().isEmpty ? 'No content yet.' : content,
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
