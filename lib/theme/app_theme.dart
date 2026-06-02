import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_animations.dart';

/// iOS-inspired glossy palette — system blue, soft surfaces, vibrant accents.
///
/// Neutral surface/text tokens are *brightness-aware*: they resolve to a light
/// or dark value based on [isDark], which [ClinixAIApp] keeps in sync with the
/// active [ThemeData]. Brand/semantic colors (primary, danger, success, …) are
/// constant because they read well on both light and dark backgrounds.
class AppTheme {
  // ── Brightness state ──────────────────────────────────────────────────────
  static bool _isDark = false;

  /// Whether the app is currently rendering in dark mode. Synced from the
  /// resolved [ThemeData.brightness] inside `MaterialApp.builder`.
  static bool get isDark => _isDark;

  /// Keeps the dynamic tokens in step with the active theme. Returns `true`
  /// when the value actually changed.
  static bool setBrightness(Brightness brightness) {
    final next = brightness == Brightness.dark;
    if (next == _isDark) return false;
    _isDark = next;
    _textCache.clear(); // text styles are brightness-dependent
    return true;
  }

  /// Caches brightness-dependent [TextStyle]s so the getters don't allocate a
  /// fresh object on every widget build (cleared when brightness flips).
  static final Map<String, TextStyle> _textCache = {};
  static TextStyle _ts(String key, TextStyle Function() build) =>
      _textCache.putIfAbsent(key, build);

  // ── Brand / semantic colors (constant in both modes) ──────────────────────
  static const Color primaryColor = Color(0xFF007AFF);
  static const Color primaryLight = Color(0xFF5AC8FA);
  static const Color secondaryColor = Color(0xFF5856D6);
  static const Color accentColor = Color(0xFFFF9500);

  static const Color successColor = Color(0xFF34C759);
  static const Color warningColor = Color(0xFFFF9500);
  static const Color dangerColor = Color(0xFFFF3B30);
  static const Color infoColor = Color(0xFF32ADE6);

  static const Color cardiologyColor = Color(0xFFFF3B30);
  static const Color neurologyColor = Color(0xFF5856D6);
  static const Color emergencyColor = Color(0xFFFF9500);
  static const Color pediatricsColor = Color(0xFF5AC8FA);
  static const Color oncologyColor = Color(0xFFAF52DE);
  static const Color surgeryColor = Color(0xFF34C759);

  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Neutral palette: explicit light + dark values ─────────────────────────
  static const Color _lightBackground = Color(0xFFF0F4FB);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceMuted = Color(0xFFE3EEFF);
  static const Color _lightSurfaceVariant = Color(0xFFE2E9F6);
  static const Color _lightDivider = Color(0xFFE8EDF8);
  static const Color _lightBorder = Color(0xFFEBEFF8);
  static const Color _lightTextPrimary = Color(0xFF1C1C1E);
  static const Color _lightTextSecondary = Color(0xFF636366);
  static const Color _lightTextTertiary = Color(0xFF8E8E93);

  static const Color _darkBackground = Color(0xFF0B0B0F);
  static const Color _darkSurface = Color(0xFF1C1C22);
  static const Color _darkSurfaceMuted = Color(0xFF2A2A33);
  static const Color _darkSurfaceVariant = Color(0xFF26262E);
  static const Color _darkDivider = Color(0xFF2C2C36);
  static const Color _darkBorder = Color(0xFF33333D);
  static const Color _darkTextPrimary = Color(0xFFF2F2F7);
  static const Color _darkTextSecondary = Color(0xFFAEAEB6);
  static const Color _darkTextTertiary = Color(0xFF8A8A93);

  // ── Brightness-aware tokens (use these in widgets) ────────────────────────
  static Color get backgroundColor =>
      _isDark ? _darkBackground : _lightBackground;
  static Color get surfaceColor => _isDark ? _darkSurface : _lightSurface;
  static Color get surfaceMuted =>
      _isDark ? _darkSurfaceMuted : _lightSurfaceMuted;
  static Color get surfaceVariant =>
      _isDark ? _darkSurfaceVariant : _lightSurfaceVariant;
  static Color get dividerColor => _isDark ? _darkDivider : _lightDivider;
  static Color get borderColor => _isDark ? _darkBorder : _lightBorder;

  static Color get textPrimary => _isDark ? _darkTextPrimary : _lightTextPrimary;
  static Color get textSecondary =>
      _isDark ? _darkTextSecondary : _lightTextSecondary;
  static Color get textTertiary =>
      _isDark ? _darkTextTertiary : _lightTextTertiary;

  /// Hairline border tuned for frosted/glass surfaces in each mode.
  static Color get glassBorder =>
      _isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE8EDF8);

  static LinearGradient get screenGradient => _isDark
      ? const LinearGradient(
          colors: [Color(0xFF15151C), Color(0xFF101015), Color(0xFF0B0B0F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )
      : const LinearGradient(
          colors: [Color(0xFFDCEBFF), Color(0xFFEBF2FF), Color(0xFFF0F4FB)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0055E5), Color(0xFF00B0F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0055E5), Color(0xFF5048D4), Color(0xFF00B0F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassShine = LinearGradient(
    colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.center,
  );

  static const LinearGradient fabGradient = LinearGradient(
    colors: [Color(0xFF0055E5), Color(0xFF00C8C2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF34C759), Color(0xFF30D158)],
  );
  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFF9500), Color(0xFFFFCC00)],
  );
  static const LinearGradient emergencyGradient = LinearGradient(
    colors: [Color(0xFFFF3B30), Color(0xFFFF6482)],
  );
  static const LinearGradient cardiologyGradient = emergencyGradient;
  static const LinearGradient neurologyGradient = LinearGradient(
    colors: [Color(0xFF5856D6), Color(0xFFAF52DE)],
  );
  static const LinearGradient surgeryGradient = successGradient;
  static const LinearGradient pediatricsGradient = LinearGradient(
    colors: [Color(0xFF5AC8FA), Color(0xFF32ADE6)],
  );

  static const LinearGradient blueGradient = primaryGradient;
  static const LinearGradient greenGradient = successGradient;
  static const LinearGradient healthGradient = heroGradient;

  static List<BoxShadow> glossyShadow({Color? tint}) => cardShadow;

  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(8));
  static const BorderRadius mediumRadius = BorderRadius.all(Radius.circular(12));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius extraLargeRadius =
      BorderRadius.all(Radius.circular(20));

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // Text styles resolve their color through the brightness-aware tokens, so
  // they are getters (cached per-brightness via [_ts] to avoid per-build allocs).
  static TextStyle get headingLarge => _ts(
        'headingLarge',
        () => TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.8,
          height: 1.15,
        ),
      );

  static TextStyle get headingMedium => _ts(
        'headingMedium',
        () => TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
      );

  static TextStyle get headingSmall => _ts(
        'headingSmall',
        () => TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      );

  static TextStyle get bodyLarge => _ts(
        'bodyLarge',
        () => TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
      );

  static TextStyle get bodyMedium => _ts(
        'bodyMedium',
        () => TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.45,
        ),
      );

  static TextStyle get bodySmall => _ts(
        'bodySmall',
        () => TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.35,
        ),
      );

  static TextStyle get labelLarge => _ts(
        'labelLarge',
        () => TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      );

  static TextStyle get labelMedium => _ts(
        'labelMedium',
        () => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          letterSpacing: 0.3,
        ),
      );

  static TextStyle get labelSmall => _ts(
        'labelSmall',
        () => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textTertiary,
          letterSpacing: 0.5,
        ),
      );

  static TextStyle get sectionLabel => _ts(
        'sectionLabel',
        () => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textTertiary,
          letterSpacing: 1.1,
        ),
      );

  /// Two-layer card shadow for visible depth. Deeper and more opaque in dark
  /// mode so elevation stays legible against near-black surfaces.
  static List<BoxShadow> get cardShadow => _isDark
      ? const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 1,
            offset: Offset(0, 1),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 1,
            offset: Offset(0, 1),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ];

  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        background: _lightBackground,
        surface: _lightSurface,
        surfaceMuted: _lightSurfaceMuted,
        divider: _lightDivider,
        border: _lightBorder,
        textPrimaryColor: _lightTextPrimary,
        textTertiaryColor: _lightTextTertiary,
        overlayStyle: SystemUiOverlayStyle.dark,
      );

  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        background: _darkBackground,
        surface: _darkSurface,
        surfaceMuted: _darkSurfaceMuted,
        divider: _darkDivider,
        border: _darkBorder,
        textPrimaryColor: _darkTextPrimary,
        textTertiaryColor: _darkTextTertiary,
        overlayStyle: SystemUiOverlayStyle.light,
      );

  /// Builds a [ThemeData] from an explicit neutral palette. Used to produce
  /// both [lightTheme] and [darkTheme] so the two stay structurally identical.
  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceMuted,
    required Color divider,
    required Color border,
    required Color textPrimaryColor,
    required Color textTertiaryColor,
    required SystemUiOverlayStyle overlayStyle,
  }) {
    final titleStyle = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: textPrimaryColor,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        surface: surface,
        onSurface: textPrimaryColor,
        error: dangerColor,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: titleStyle,
        systemOverlayStyle: overlayStyle,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: largeRadius,
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primaryColor.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? primaryColor : textTertiaryColor,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primaryColor : textTertiaryColor,
            size: 24,
          );
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: lg, vertical: md),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: xl, vertical: md),
          shape: RoundedRectangleBorder(borderRadius: mediumRadius),
          elevation: 0,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: lg, vertical: 2),
      ),
    );
  }
}

/// Frosted glass surface — WhatsApp / iOS style.
class GlossyPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool enableBlur;
  final Color? tint;

  const GlossyPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 16,
    this.enableBlur = false,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppTheme.glassBorder,
          width: 0.8,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );

    // NOTE: [enableBlur] is intentionally a no-op. This panel's fill is an
    // opaque surface, so a BackdropFilter behind it is never visible — it only
    // costs GPU time every frame (a real source of scroll jank on Android).
    // Kept as a parameter for call-site compatibility.
    return content;
  }
}

/// Full-width frosted bar (chat input, nav).
class GlassBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppTheme.lg,
      vertical: AppTheme.md,
    ),
  });

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isolates the (expensive) backdrop blur from the rest of
    // the tree; a lower sigma keeps the frosted look at a fraction of the cost.
    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.78),
            border: Border(
              top: BorderSide(
                color: AppTheme.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: child,
          ),
        ),
      ),
    );
  }
}

/// One tab in [GlossyBottomNav].
class GlossyNavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const GlossyNavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Simple compact bottom nav — clean white surface, icon + label, blue active.
class GlossyBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<GlossyNavDestination> destinations;

  const GlossyBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: AppTheme.glassBorder, width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x33000000) : const Color(0x0A000000),
            blurRadius: 2,
            offset: const Offset(0, -1),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: dark ? const Color(0x4D000000) : const Color(0x12000000),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(destinations.length, (i) {
              final d = destinations[i];
              final sel = i == selectedIndex;
              return Expanded(
                child: _SimpleNavSlot(
                  selected: sel,
                  icon: d.icon,
                  activeIcon: d.activeIcon,
                  label: d.label,
                  onTap: () => onSelect(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _SimpleNavSlot extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  const _SimpleNavSlot({
    required this.selected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primaryColor : AppTheme.textTertiary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (selected)
            Container(
              width: 32,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          else
            const SizedBox(height: 9),
          Icon(selected ? activeIcon : icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.lg),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // PressableScale gives cheap tap feedback (and is a no-op when onTap is
    // null), so non-interactive cards stay completely static.
    return PressableScale(
      onTap: onTap,
      child: GlossyPanel(padding: padding, child: child),
    );
  }
}

class GlossyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final LinearGradient? gradient;
  final EdgeInsets margin;

  const GlossyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.lg),
    this.borderRadius = AppTheme.largeRadius,
    this.backgroundColor,
    this.onTap,
    this.gradient,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null
                ? (backgroundColor ?? AppTheme.surfaceColor)
                : null,
            borderRadius: borderRadius,
            border: Border.all(
              color: gradient != null
                  ? Colors.white.withValues(alpha: 0.25)
                  : AppTheme.glassBorder,
              width: 0.8,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              children: [
                if (gradient != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 72,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: AppTheme.glassShine),
                    ),
                  ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class IosButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;
  final Widget? iconWidget;
  final bool isOutlined;

  const IosButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor = AppTheme.primaryColor,
    this.foregroundColor = Colors.white,
    this.icon,
    this.iconWidget,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.primaryColor),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.xl,
            vertical: AppTheme.lg,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppTheme.mediumRadius),
        ),
        child: _buildChild(context, outlined: true),
      );
    }
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.xl,
          vertical: AppTheme.lg,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppTheme.mediumRadius),
      ),
      child: _buildChild(context),
    );
  }

  Widget _buildChild(BuildContext context, {bool outlined = false}) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(
            outlined ? AppTheme.primaryColor : foregroundColor,
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconWidget != null) ...[
          iconWidget!,
          const SizedBox(width: AppTheme.sm),
        ],
        if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: AppTheme.sm),
        ],
        Text(label),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? actionLabel;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.lg,
        AppTheme.xl,
        AppTheme.lg,
        AppTheme.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.headingSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: AppTheme.xs),
                  Text(subtitle!, style: AppTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onTap != null)
            TextButton(onPressed: onTap, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor = AppTheme.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: AppTheme.md),
          Text(label, style: AppTheme.bodySmall),
          const SizedBox(height: AppTheme.xs),
          Text(value, style: AppTheme.headingMedium),
        ],
      ),
    );
  }
}
