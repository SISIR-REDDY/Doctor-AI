import 'package:flutter/material.dart';

/// Premium palette for consultation result screens.
abstract final class ConsultationPalette {
  static const Color charcoal = Color(0xFF1E293B);
  static const Color slate = Color(0xFF334155);
  static const Color gold = Color(0xFFC9A227);
  static const Color goldMuted = Color(0xFFD4AF37);
  static const Color cream = Color(0xFFF4F2EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1F2430);
  static const Color muted = Color(0xFF64748B);

  static const Color transcript = Color(0xFF0D9488);
  static const Color summary = Color(0xFF6D28D9);
  static const Color prescription = Color(0xFF047857);
  static const Color warning = Color(0xFFEA580C);
  static const Color doctor = Color(0xFF5B4FCF);
  static const Color patient = Color(0xFF0D9488);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [charcoal, slate],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
