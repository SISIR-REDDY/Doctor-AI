import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../theme/app_theme.dart';

/// Renders AI-generated markdown text attractively.
///
/// Supports headings, bold, bullets, blockquotes, and inline code.
/// Use [isLoading] to show a spinner while the AI response is in-flight.
class AiSummaryView extends StatelessWidget {
  final String content;
  final bool isLoading;
  final String title;
  final IconData icon;

  const AiSummaryView({
    super.key,
    required this.content,
    this.isLoading = false,
    this.title = 'AI Analysis',
    this.icon = Icons.auto_awesome_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.07),
            AppTheme.secondaryColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header bar ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.lg, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 15),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryColor),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        color: AppTheme.successColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppTheme.lg),
            child: isLoading
                ? _LoadingPlaceholder()
                : content.isEmpty
                    ? Text(
                        'Analysis not available.',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.textSecondary),
                      )
                    : MarkdownBody(
                        data: content,
                        styleSheet: _styleSheet(),
                        softLineBreak: true,
                      ),
          ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _styleSheet() => MarkdownStyleSheet(
        // Headings — each level gets a distinct brand colour
        h1: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryColor,
          height: 1.3,
          letterSpacing: -0.2,
        ),
        h2: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.secondaryColor,
          height: 1.4,
        ),
        h3: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.infoColor,
          height: 1.4,
        ),
        // Body text
        p: TextStyle(
          fontSize: 13,
          color: AppTheme.textPrimary,
          height: 1.7,
        ),
        // Bold → orange accent so it pops
        strong: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppTheme.accentColor,
        ),
        // Italic → muted
        em: TextStyle(
          fontStyle: FontStyle.italic,
          color: AppTheme.textSecondary,
        ),
        // Bullets → green
        listBullet: const TextStyle(
          color: AppTheme.successColor,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        listBulletPadding: const EdgeInsets.only(right: 6),
        listIndent: 16,
        // Inline code
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: AppTheme.dangerColor,
          backgroundColor: AppTheme.dangerColor.withValues(alpha: 0.08),
        ),
        // Code block
        codeblockDecoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        // Blockquote → info blue strip
        blockquote: TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondary,
          height: 1.6,
        ),
        blockquoteDecoration: BoxDecoration(
          color: AppTheme.infoColor.withValues(alpha: 0.08),
          border: Border(
            left: BorderSide(color: AppTheme.infoColor, width: 3),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        blockquotePadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        // Horizontal rule
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
                color: AppTheme.dividerColor.withValues(alpha: 0.6), width: 1),
          ),
        ),
        // Spacing between blocks
        h1Padding: const EdgeInsets.only(top: 14, bottom: 4),
        h2Padding: const EdgeInsets.only(top: 12, bottom: 4),
        h3Padding: const EdgeInsets.only(top: 8, bottom: 2),
        pPadding: const EdgeInsets.only(bottom: 2),
      );
}

class _LoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analyzing your document…',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        // Shimmer-like grey bars suggesting incoming text
        ...List.generate(
          4,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 10,
              width: i == 3 ? 120 : double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
