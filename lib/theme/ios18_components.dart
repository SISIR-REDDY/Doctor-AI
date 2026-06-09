import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// Clinix Design System v2 — "Clean iOS 18 / Health-app" language.
///
/// Principles:
///   • Large, bold collapsing titles (iOS large-title navigation).
///   • Grouped, inset cards on a soft background — like Settings / Health.
///   • Generous spacing, restrained color, subtle (not heavy) depth.
///   • Continuous-corner squircles and spring press feedback throughout.
///
/// These components are additive; existing screens keep working while we
/// migrate them one by one onto this language.
/// ──────────────────────────────────────────────────────────────────────────
class DS {
  DS._();

  // Corner radii — iOS 18 favors larger, continuous corners.
  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 22;
  static const double rXl = 28;

  // Inset used for grouped content (iOS list inset is ~16–20).
  static const double gutter = 18;

  static BorderRadius radius(double r) =>
      BorderRadius.all(Radius.circular(r));

  /// Continuous ("squircle") radius — the smooth Apple corner.
  static BorderRadius squircle(double r) =>
      BorderRadius.all(Radius.circular(r));

  /// Soft, low, single-layer shadow. Health-app cards float gently, not loudly.
  static List<BoxShadow> softShadow({double y = 6, double blur = 18}) =>
      AppTheme.isDark
          ? [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.45),
                blurRadius: blur,
                offset: Offset(0, y),
              ),
            ]
          : [
              BoxShadow(
                color: const Color(0xFF1B2A4A).withValues(alpha: 0.06),
                blurRadius: blur,
                offset: Offset(0, y),
              ),
            ];
}

/// A screen scaffold with an iOS-18 large collapsing title.
///
/// Renders a [CustomScrollView] with a [SliverAppBar.large]; pass your content
/// as [slivers] (already-sliver widgets) or [children] (boxed into a list).
class LargeTitleScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? children;
  final List<Widget>? slivers;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final Widget? bottomBar;
  final EdgeInsets contentPadding;
  final Future<void> Function()? onRefresh;

  const LargeTitleScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.children,
    this.slivers,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.bottomBar,
    this.contentPadding =
        const EdgeInsets.fromLTRB(DS.gutter, 8, DS.gutter, 120),
    this.onRefresh,
  }) : assert(children != null || slivers != null,
            'Provide children or slivers');

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.backgroundColor;

    final content = CustomScrollView(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar.large(
          pinned: true,
          backgroundColor: bg,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: leading,
          actions: actions,
          systemOverlayStyle: AppTheme.isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          expandedHeight: subtitle == null ? null : 132,
          title: Text(title,
              style: AppTheme.headingSmall
                  .copyWith(fontWeight: FontWeight.w600)),
          flexibleSpace: FlexibleSpaceBar(
            expandedTitleScale: 1.9,
            titlePadding:
                const EdgeInsets.only(left: DS.gutter, bottom: 14, right: 16),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17, // scaled up ~1.9x when expanded
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (subtitle != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DS.gutter, 0, DS.gutter, 4),
              child: Text(subtitle!,
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textSecondary)),
            ),
          ),
        if (slivers != null)
          ...slivers!
        else
          SliverPadding(
            padding: contentPadding,
            sliver: SliverList(
              delegate: SliverChildListDelegate(children!),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
      body: onRefresh == null
          ? content
          : RefreshIndicator(
              onRefresh: onRefresh!,
              color: AppTheme.primaryColor,
              child: content,
            ),
    );
  }
}

/// A titled, inset group of rows — the iOS "grouped list section".
///
/// [header] is a small all-caps label above the card (optional); the children
/// are stacked inside one rounded surface with hairline separators between them.
class InsetSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;
  final EdgeInsets margin;

  const InsetSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: 22),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 8),
              child: Text(
                header!.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: DS.squircle(DS.rLg),
              border: Border.all(color: AppTheme.glassBorder, width: 0.7),
              boxShadow: DS.softShadow(),
            ),
            child: ClipRRect(
              borderRadius: DS.squircle(DS.rLg),
              child: Column(
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i != children.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 56),
                        child: Divider(
                          height: 0.7,
                          thickness: 0.7,
                          color: AppTheme.dividerColor,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (footer != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 8),
              child: Text(footer!,
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textTertiary, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single tappable row inside an [InsetSection] — leading icon chip, title,
/// optional subtitle/value, and a chevron. The Health/Settings list row.
class InsetRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const InsetRow({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor = AppTheme.primaryColor,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: DS.squircle(9),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTheme.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(subtitle!,
                          style: AppTheme.bodySmall.copyWith(fontSize: 12)),
                    ),
                ],
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(value!,
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textSecondary)),
              ),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(CupertinoIcons.chevron_right,
                    size: 15, color: AppTheme.textTertiary),
              ),
          ],
        ),
      ),
    );
  }
}

/// A standalone inset card (not part of a grouped list) — for hero/summary
/// content. Optional [gradient] for emphasis cards; otherwise a clean surface.
class InsetCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Gradient? gradient;
  final Color? color;
  final VoidCallback? onTap;
  final double radius;

  const InsetCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.only(bottom: 16),
    this.gradient,
    this.color,
    this.onTap,
    this.radius = DS.rLg,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: _Pressable(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null
                ? (color ?? AppTheme.surfaceColor)
                : null,
            borderRadius: DS.squircle(radius),
            border: gradient == null
                ? Border.all(color: AppTheme.glassBorder, width: 0.7)
                : null,
            boxShadow: gradient != null
                ? [
                    BoxShadow(
                      color: (gradient as LinearGradient)
                          .colors
                          .first
                          .withValues(alpha: 0.30),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : DS.softShadow(),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Small all-caps section label used outside grouped lists.
class DSSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const DSSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
      child: Row(
        children: [
          Text(text.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppTheme.textTertiary,
              )),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A clean filled pill button — full width by default, optional icon.
class DSButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;
  final Color color;
  final Color foreground;
  final bool tonal;

  const DSButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.loading = false,
    this.color = AppTheme.primaryColor,
    this.foreground = Colors.white,
    this.tonal = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = tonal ? color.withValues(alpha: 0.14) : color;
    final fg = tonal ? color : foreground;
    return _Pressable(
      onTap: loading ? null : onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: DS.squircle(DS.rMd),
          boxShadow: tonal ? null : DS.softShadow(y: 4, blur: 12),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, valueColor: AlwaysStoppedAnimation(fg)),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(label,
                      style: TextStyle(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }
}

/// Spring-press wrapper used by every interactive DS component. Scales down a
/// touch with a quick spring and fires light haptics — the Apple "alive" feel.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Pressable({required this.child, this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    lowerBound: 0,
    upperBound: 1,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) => _c.forward();
  void _up(_) => _c.reverse();

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: () => _c.reverse(),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap!();
      },
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(
          scale: 1 - _c.value * 0.03,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Public spring-press wrapper for screens that want the feedback on custom UI.
class DSPressable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const DSPressable({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) =>
      _Pressable(onTap: onTap, child: child);
}
