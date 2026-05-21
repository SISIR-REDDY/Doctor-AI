import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Renders AI-generated clinical text as formatted markdown.
///
/// Handles the common mess Gemini returns:
///  - `**bold**` labels
///  - `- bullet` lists
///  - `*italic*` notes
///  - bare plain text (no markdown) — renders cleanly as-is
class ClinicalMd extends StatelessWidget {
  final String data;
  final double fontSize;
  final Color? color;
  final Color? bulletColor;
  final bool selectable;

  const ClinicalMd(
    this.data, {
    super.key,
    this.fontSize = 14,
    this.color,
    this.bulletColor,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final ink = color ?? const Color(0xFF1E293B);
    final bullet = bulletColor ?? ink;

    final sheet = MarkdownStyleSheet(
      p: TextStyle(fontSize: fontSize, height: 1.55, color: ink),
      strong: TextStyle(
        fontSize: fontSize,
        height: 1.55,
        color: ink,
        fontWeight: FontWeight.w700,
      ),
      em: TextStyle(
        fontSize: fontSize,
        height: 1.55,
        color: ink,
        fontStyle: FontStyle.italic,
      ),
      listBullet: TextStyle(fontSize: fontSize, color: bullet),
      listIndent: 16,
      blockSpacing: 4,
      h1: TextStyle(
          fontSize: fontSize + 2,
          fontWeight: FontWeight.w700,
          color: ink,
          height: 1.4),
      h2: TextStyle(
          fontSize: fontSize + 1,
          fontWeight: FontWeight.w700,
          color: ink,
          height: 1.4),
      h3: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: ink,
          height: 1.4),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: ink.withValues(alpha: 0.12), width: 1),
        ),
      ),
    );

    // Strip any fenced code blocks (```...```) that Gemini occasionally
    // wraps around structured output — they look like raw triple-backticks.
    final cleaned = data
        .replaceAll(RegExp(r'```[a-z]*\n?', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();

    if (cleaned.isEmpty) return const SizedBox.shrink();

    return MarkdownBody(
      data: cleaned,
      styleSheet: sheet,
      selectable: selectable,
      shrinkWrap: true,
    );
  }
}
