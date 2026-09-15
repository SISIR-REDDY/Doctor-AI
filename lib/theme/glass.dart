import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'ios18_components.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// Liquid-glass layer of the design system (iOS 26-era): translucent floating
/// surfaces that blur what scrolls beneath them, a floating pill tab bar,
/// hero buttons and stat tiles. Sits on top of [DS] / ios18_components.
/// ──────────────────────────────────────────────────────────────────────────

/// A frosted, translucent surface with a hairline highlight border.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final double blur;
  final Color? tint;
  final bool shadow;

  const GlassPanel({
    super.key,
    required this.child,
    this.radius = DS.rXl,
    this.padding = EdgeInsets.zero,
    this.blur = 22,
    this.tint,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final fill = tint ??
        (dark
            ? const Color(0xFF1C1C22).withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.74));
    return Container(
      decoration: BoxDecoration(
        borderRadius: DS.squircle(radius),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: (dark ? Colors.black : const Color(0xFF1B2A4A))
                      .withValues(alpha: dark ? 0.55 : 0.14),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: DS.squircle(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: DS.squircle(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.10 : 0.65),
                width: 0.8,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: dark ? 0.06 : 0.35),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Floating pill tab bar. Place it in `Scaffold.bottomNavigationBar` with
/// `extendBody: true` so content scrolls underneath the glass.
class GlassTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<GlassTab> tabs;

  const GlassTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.tabs,
  });

  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? bottomInset - 4 : 12),
      child: GlassPanel(
        radius: 34,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: SizedBox(
          height: height - 12,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _GlassTabSlot(
                    tab: tabs[i],
                    selected: i == selectedIndex,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(i);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const GlassTab({required this.icon, required this.activeIcon, required this.label});
}

class _GlassTabSlot extends StatelessWidget {
  final GlassTab tab;
  final bool selected;
  final VoidCallback onTap;
  const _GlassTabSlot({required this.tab, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primaryColor : AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: AppTheme.isDark ? 0.22 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? tab.activeIcon : tab.icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width primary call to action — the one thing to do on a screen.
class HeroButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool loading;
  final Gradient? gradient;
  final Color? color;
  final Color foreground;
  final double height;

  const HeroButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.loading = false,
    this.gradient,
    this.color,
    this.foreground = Colors.white,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return DSPressable(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.55,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: color == null ? (gradient ?? AppTheme.primaryGradient) : null,
            color: color,
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: [
              BoxShadow(
                color: (color ?? AppTheme.primaryColor).withValues(alpha: 0.30),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: foreground, size: 21),
                        const SizedBox(width: 9),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Quiet secondary action (tonal pill).
class TonalButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;
  final double height;

  const TonalButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.color,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryColor;
    return DSPressable(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: c.withValues(alpha: AppTheme.isDark ? 0.20 : 0.11),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: c, size: 19),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(color: c, fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big number + label, used on the Home money card and case headers.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;
  final Color? foreground;
  final bool compact;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
    this.foreground,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? AppTheme.textPrimary;
    final sub = foreground?.withValues(alpha: 0.78) ?? AppTheme.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: accent ?? sub),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 11.5 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: sub,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 20 : 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: fg,
            height: 1.05,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Selectable option card for onboarding / pickers.
class ChoiceCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;
  final bool multi;

  const ChoiceCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.selected,
    required this.onTap,
    this.multi = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.primaryColor;
    return DSPressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? p.withValues(alpha: AppTheme.isDark ? 0.18 : 0.08)
              : AppTheme.surfaceColor,
          borderRadius: DS.squircle(DS.rLg),
          border: Border.all(
            color: selected ? p : AppTheme.glassBorder,
            width: selected ? 1.6 : 0.8,
          ),
          boxShadow: selected ? null : DS.softShadow(y: 3, blur: 10),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!,
                          style: AppTheme.bodySmall
                              .copyWith(color: AppTheme.textSecondary)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? p : Colors.transparent,
                shape: multi ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: multi ? BorderRadius.circular(7) : null,
                border: Border.all(
                  color: selected ? p : AppTheme.textTertiary.withValues(alpha: 0.6),
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const Icon(CupertinoIcons.checkmark, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded status chip.
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const Pill(this.label, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.isDark ? 0.24 : 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          // Truncate rather than overflow when the caller is tight on width
          // (narrow phones, large accessibility text).
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular icon badge used as list leading / feature icon.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool filled;
  const IconBadge(this.icon, {super.key, required this.color, this.size = 40, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: AppTheme.isDark ? 0.22 : 0.13),
        borderRadius: DS.squircle(size * 0.3),
      ),
      child: Icon(icon, color: filled ? Colors.white : color, size: size * 0.52),
    );
  }
}

/// Page-level top bar for non-scrolling flow screens (back + progress).
class FlowTopBar extends StatelessWidget {
  final VoidCallback? onBack;
  final double? progress;
  final Widget? trailing;
  const FlowTopBar({super.key, this.onBack, this.progress, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    icon: Icon(CupertinoIcons.chevron_back, color: AppTheme.textPrimary),
                  ),
          ),
          Expanded(
            child: progress == null
                ? const SizedBox()
                : ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => LinearProgressIndicator(
                        value: v,
                        minHeight: 4,
                        backgroundColor: AppTheme.dividerColor,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}
