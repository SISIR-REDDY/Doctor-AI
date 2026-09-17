import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/insurance_regions.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/analytics_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/remote_config_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';
import '../../theme/motion.dart';
import '../legal/legal_screens.dart';

/// Clinix Pro paywall. Purchases go through the App Store / Play Store via
/// RevenueCat; entitlement resolution lives in [EntitlementService].
class PaywallScreen extends StatefulWidget {
  /// The quota op the user just hit ('audit', 'letter', 'explain', 'analyze',
  /// 'chat'), or null when opened from a Pro card. Drives the headline so the
  /// screen answers the question they actually have.
  final String? reason;
  const PaywallScreen({super.key, this.reason});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin, SceneTimeline {
  Offerings? _offerings;
  bool _loading = true;
  bool _buying = false;
  String _selected = 'yearly';
  Stream<List<InsuranceClaim>>? _claims;

  @override
  Duration get sceneDuration => const Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    Analytics.screen('paywall');
    final uid = context.read<HealthDataProvider>().uid;
    if (uid != null) _claims = FirestoreService().watchClaims(uid);
    playScene();
    _load();
  }

  /// Headline + support line for the situation the user is in.
  (String, String) _pitch(double disputable, String currency) {
    final money = disputable > 0 ? formatMoney(disputable, currency) : null;
    switch (widget.reason) {
      case 'audit':
        return (
          money == null
              ? 'Your free audit is used up this month.'
              : '$money is sitting in your bills.',
          'Pro audits every bill, every time — and drafts the dispute for each finding.',
        );
      case 'letter':
        return (
          'Your free letter is used this month.',
          'Pro drafts every dispute and appeal, with your policy and rights cited.',
        );
      case 'explain':
        return (
          'Your free denial analyses are used.',
          'Pro explains every denial and builds the appeal, unlimited.',
        );
      case 'analyze':
        return (
          'You’ve scanned 6 documents this month.',
          'Pro reads unlimited bills, statements, letters and lab reports.',
        );
      case 'chat':
        return (
          'Your free chats are used this month.',
          'Pro answers unlimited questions, grounded in your own records.',
        );
      default:
        return (
          money == null
              ? 'Stop paying for other people’s mistakes.'
              : '$money you could dispute — right now.',
          money == null
              ? 'Up to 8 in 10 bills contain an error. Pro checks every one.'
              : 'Pro drafts the letter for every finding. One corrected charge can pay for a year.',
        );
    }
  }

  /// Trial wording when the store product carries an introductory offer.
  String? _trialLabel(Package? pkg) {
    final intro = pkg?.storeProduct.introductoryPrice;
    if (intro == null || intro.price != 0) return null;
    final unit = switch (intro.periodUnit) {
      PeriodUnit.day => 'day',
      PeriodUnit.week => 'week',
      PeriodUnit.month => 'month',
      PeriodUnit.year => 'year',
      _ => 'day',
    };
    final n = intro.periodNumberOfUnits;
    return 'Start ${n == 1 ? 'a' : n}-$unit free trial';
  }

  Future<void> _load() async {
    final o = await EntitlementService.instance.loadOfferings();
    if (mounted) {
      setState(() {
        _offerings = o;
        _loading = false;
      });
    }
  }

  Package? get _monthly => _offerings?.current?.monthly;
  Package? get _annual => _offerings?.current?.annual;
  Package? get _chosen => _selected == 'yearly' ? _annual : _monthly;

  Future<void> _buy() async {
    final pkg = _chosen;
    if (pkg == null) return;
    setState(() => _buying = true);
    try {
      Analytics.purchaseStarted(pkg.storeProduct.identifier);
      final ok = await EntitlementService.instance.purchase(pkg);
      if (ok) {
        Analytics.purchaseCompleted(pkg.storeProduct.identifier);
        HapticFeedback.heavyImpact();
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _buying = true);
    try {
      final ok = await EntitlementService.instance.restore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Pro restored.' : 'No active subscription found.'),
        ),
      );
      if (ok) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ent = context.watch<EntitlementService>();
    final rc = RemoteConfigService.instance;
    final monthlyPrice =
        _monthly?.storeProduct.priceString ??
        rc.string('pro_monthly_price', r'$9.99');
    final yearlyPrice =
        _annual?.storeProduct.priceString ??
        rc.string('pro_yearly_price', r'$79.99');
    // Saving is computed from the store's real prices, never hard-coded, so
    // the badge stays true when pricing changes per country or promotion.
    final mp = _monthly?.storeProduct.price ?? 9.99;
    final yp = _annual?.storeProduct.price ?? 79.99;
    final savePct = mp > 0 ? (((mp * 12 - yp) / (mp * 12)) * 100).round() : 0;
    final saveBadge = savePct >= 5 ? 'Save $savePct%' : null;
    final configured = ent.isConfigured && _offerings?.current != null;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppTheme.isDark
                ? const [Color(0xFF17122B), Color(0xFF0B0B0F)]
                : const [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0xFFFFFFFF),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.xmark,
                        color: AppTheme.textPrimary,
                      ),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _buying ? null : _restore,
                      child: const Text('Restore'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    StreamBuilder<List<InsuranceClaim>>(
                      stream: _claims,
                      builder: (context, snap) {
                        final claims = snap.data ?? const <InsuranceClaim>[];
                        final open = claims.where((c) => !c.isClosed);
                        final disputable = open.fold<double>(
                          0,
                          (n, c) => n + c.potentialSaving,
                        );
                        final currency = open.isNotEmpty
                            ? open.first.currencyCode
                            : 'USD';
                        final (title, support) = _pitch(disputable, currency);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Their own number, counting up: the strongest argument
                            // the screen can make, because it is true and theirs.
                            if (disputable > 0)
                              FadeSlide(
                                animation: scene,
                                interval: const Interval(
                                  0.0,
                                  0.4,
                                  curve: Motion.springHeavy,
                                ),
                                dy: 16,
                                from: 0.96,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    16,
                                    18,
                                    16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor.withValues(
                                      alpha: AppTheme.isDark ? 0.18 : 0.10,
                                    ),
                                    borderRadius: DS.squircle(DS.rLg),
                                    border: Border.all(
                                      color: AppTheme.successColor.withValues(
                                        alpha: 0.35,
                                      ),
                                      width: 0.9,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'FOUND IN YOUR BILLS',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: AppTheme.successColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      CountUp(
                                        animation: scene,
                                        interval: const Interval(
                                          0.1,
                                          0.7,
                                          curve: Curves.easeOutCubic,
                                        ),
                                        value: disputable,
                                        format: (v) => formatMoney(v, currency),
                                        style: TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1.4,
                                          height: 1.05,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'across ${open.length} open ${open.length == 1 ? 'case' : 'cases'} · not yet disputed',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (disputable > 0) const SizedBox(height: 18),
                            FadeSlide(
                              animation: scene,
                              interval: const Interval(
                                0.08,
                                0.5,
                                curve: Motion.enter,
                              ),
                              dy: 14,
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                  height: 1.08,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FadeSlide(
                              animation: scene,
                              interval: const Interval(
                                0.18,
                                0.6,
                                curve: Motion.enter,
                              ),
                              dy: 14,
                              child: Text(
                                support,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  height: 1.45,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    FadeSlide(
                      animation: scene,
                      interval: const Interval(0.3, 0.75, curve: Motion.enter),
                      dy: 18,
                      child: InsetCard(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: const Column(
                          children: [
                            _Feature(
                              icon: CupertinoIcons.doc_text_search,
                              color: Color(0xFFFF3B30),
                              title: 'Unlimited bill audits',
                              body:
                                  'Every line checked against fair-price references.',
                            ),
                            _Feature(
                              icon: CupertinoIcons.paperplane_fill,
                              color: Color(0xFF007AFF),
                              title: 'Appeal & dispute letters',
                              body:
                                  'Drafted from your documents, ready to send, exportable as PDF.',
                            ),
                            _Feature(
                              icon: CupertinoIcons.bell_fill,
                              color: Color(0xFFFF9500),
                              title: 'Deadline tracking',
                              body:
                                  'Appeal windows added automatically, with reminders.',
                            ),
                            _Feature(
                              icon: CupertinoIcons.chat_bubble_2_fill,
                              color: Color(0xFF5856D6),
                              title: 'Ask anything about your coverage',
                              body:
                                  'Answers grounded in your own policy and statements.',
                            ),
                            _Feature(
                              icon: CupertinoIcons.lab_flask_solid,
                              color: Color(0xFF32ADE6),
                              title: 'Unlimited reports & records',
                              body:
                                  'Lab results decoded with trends; every document in the vault.',
                            ),
                            _Feature(
                              icon: CupertinoIcons.person_2_fill,
                              color: Color(0xFF34C759),
                              title: 'Family cases',
                              body:
                                  'Handle bills and claims for dependants too.',
                              last: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Say what stays free. A paywall that hides this reads as
                    // bait-and-switch in reviews; one that states it reads fair.
                    Text(
                      'Free always includes 6 document scans, 1 bill audit, 1 letter, 2 denial analyses and 20 assistant chats a month — plus medications, reminders and your vault.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _PlanCard(
                            title: 'Yearly',
                            price: yearlyPrice,
                            per: '/ year',
                            badge: saveBadge,
                            selected: _selected == 'yearly',
                            onTap: () => setState(() => _selected = 'yearly'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PlanCard(
                            title: 'Monthly',
                            price: monthlyPrice,
                            per: '/ month',
                            selected: _selected == 'monthly',
                            onTap: () => setState(() => _selected = 'monthly'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (ent.isPro)
                      const Center(
                        child: Pill(
                          'You’re on Pro',
                          color: Color(0xFF34C759),
                          icon: CupertinoIcons.checkmark_seal_fill,
                        ),
                      )
                    else
                      FadeSlide(
                        animation: scene,
                        interval: const Interval(
                          0.5,
                          0.9,
                          curve: Motion.springHeavy,
                        ),
                        dy: 14,
                        from: 0.97,
                        child: HeroButton(
                          label: !configured
                              ? (_loading
                                    ? 'Loading…'
                                    : 'Purchases coming soon')
                              : (_trialLabel(_chosen) ??
                                    (_selected == 'yearly'
                                        ? 'Get Pro · $yearlyPrice / year'
                                        : 'Get Pro · $monthlyPrice / month')),
                          icon: configured
                              ? CupertinoIcons.lock_open_fill
                              : null,
                          loading: _buying,
                          onTap: configured && !_loading ? _buy : null,
                        ),
                      ),
                    if (!ent.isPro && _trialLabel(_chosen) != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Then ${_selected == 'yearly' ? '$yearlyPrice / year' : '$monthlyPrice / month'}. Cancel before the trial ends and pay nothing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Auto-renews until cancelled. Cancel any time in your ${isIOS ? 'App Store' : 'Google Play'} subscriptions. Clinix provides information and drafts — not medical, legal or financial advice — and does not guarantee any refund or appeal outcome.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Link('Terms', () => _open(context, LegalDoc.terms)),
                        Text(
                          '  ·  ',
                          style: TextStyle(color: AppTheme.textTertiary),
                        ),
                        _Link(
                          'Privacy',
                          () => _open(context, LegalDoc.privacy),
                        ),
                        Text(
                          '  ·  ',
                          style: TextStyle(color: AppTheme.textTertiary),
                        ),
                        _Link(
                          'Manage',
                          () => launchUrl(
                            Uri.parse(
                              isIOS
                                  ? 'https://apps.apple.com/account/subscriptions'
                                  : 'https://play.google.com/store/account/subscriptions',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, LegalDoc doc) => Navigator.push(
    context,
    CupertinoPageRoute(builder: (_) => LegalDocumentScreen(doc: doc)),
  );
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final bool last;
  const _Feature({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: last ? 8 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon, color: color, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  body,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String per;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;
  const _PlanCard({
    required this.title,
    required this.price,
    required this.per,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  static const _p = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    return DSPressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      // Selection springs up a touch and lifts; the other card settles back.
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.965,
        duration: const Duration(milliseconds: 380),
        curve: Motion.spring,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Motion.enter,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: selected
                ? _p.withValues(alpha: AppTheme.isDark ? 0.2 : 0.07)
                : AppTheme.surfaceColor,
            borderRadius: DS.squircle(DS.rLg),
            border: Border.all(
              color: selected ? _p : AppTheme.glassBorder,
              width: selected ? 1.6 : 0.8,
            ),
            boxShadow: selected ? DS.softShadow(y: 6, blur: 18) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Radio dot makes the selection state unambiguous.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? _p : Colors.transparent,
                      border: Border.all(
                        color: selected ? _p : AppTheme.textTertiary,
                        width: 1.6,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            CupertinoIcons.checkmark,
                            size: 11,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (badge != null) Pill(badge!, color: AppTheme.successColor),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                price,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                per,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Link(this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryColor,
      ),
    ),
  );
}
