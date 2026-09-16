import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/app_error_handler.dart';
import '../../services/analytics_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/remote_config_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';
import '../legal/legal_screens.dart';

/// Clinix Pro paywall. Purchases go through the App Store / Play Store via
/// RevenueCat; entitlement resolution lives in [EntitlementService].
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  bool _loading = true;
  bool _buying = false;
  String _selected = 'yearly';

  @override
  void initState() {
    super.initState();
    Analytics.screen('paywall');
    _load();
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
        SnackBar(content: Text(ok ? 'Pro restored.' : 'No active subscription found.')),
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
    final monthlyPrice = _monthly?.storeProduct.priceString ?? rc.string('pro_monthly_price', r'$9.99');
    final yearlyPrice = _annual?.storeProduct.priceString ?? rc.string('pro_yearly_price', r'$79.99');
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
                : const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
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
                      icon: Icon(CupertinoIcons.xmark, color: AppTheme.textPrimary),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const Spacer(),
                    TextButton(onPressed: _buying ? null : _restore, child: const Text('Restore')),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF5856D6).withValues(alpha: 0.35),
                                blurRadius: 28,
                                offset: const Offset(0, 12)),
                          ],
                        ),
                        child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 40),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Clinix Pro',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      'One recovered charge usually pays for a year.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 24),
                    InsetCard(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: const Column(
                        children: [
                          _Feature(icon: CupertinoIcons.doc_text_search, color: Color(0xFFFF3B30),
                              title: 'Unlimited bill audits', body: 'Every line checked against fair-price references.'),
                          _Feature(icon: CupertinoIcons.paperplane_fill, color: Color(0xFF007AFF),
                              title: 'Appeal & dispute letters', body: 'Drafted from your documents, ready to send, exportable as PDF.'),
                          _Feature(icon: CupertinoIcons.bell_fill, color: Color(0xFFFF9500),
                              title: 'Deadline tracking', body: 'Appeal windows added automatically, with reminders.'),
                          _Feature(icon: CupertinoIcons.chat_bubble_2_fill, color: Color(0xFF5856D6),
                              title: 'Ask anything about your coverage', body: 'Answers grounded in your own policy and statements.'),
                          _Feature(icon: CupertinoIcons.person_2_fill, color: Color(0xFF34C759),
                              title: 'Family cases', body: 'Handle bills and claims for dependants too.', last: true),
                        ],
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
                            badge: 'Save 33%',
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
                        child: Pill('You’re on Pro', color: Color(0xFF34C759), icon: CupertinoIcons.checkmark_seal_fill),
                      )
                    else
                      HeroButton(
                        label: configured ? 'Continue' : (_loading ? 'Loading…' : 'Purchases coming soon'),
                        icon: configured ? CupertinoIcons.lock_open_fill : null,
                        loading: _buying,
                        onTap: configured && !_loading ? _buy : null,
                        gradient: const LinearGradient(colors: [Color(0xFF5856D6), Color(0xFF007AFF)]),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Auto-renews until cancelled. Cancel any time in your ${isIOS ? 'App Store' : 'Google Play'} subscriptions. Clinix provides information and drafts — not medical, legal or financial advice — and does not guarantee any refund or appeal outcome.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textTertiary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Link('Terms', () => _open(context, LegalDoc.terms)),
                        Text('  ·  ', style: TextStyle(color: AppTheme.textTertiary)),
                        _Link('Privacy', () => _open(context, LegalDoc.privacy)),
                        Text('  ·  ', style: TextStyle(color: AppTheme.textTertiary)),
                        _Link('Manage', () => launchUrl(Uri.parse(isIOS
                            ? 'https://apps.apple.com/account/subscriptions'
                            : 'https://play.google.com/store/account/subscriptions'))),
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

  void _open(BuildContext context, LegalDoc doc) =>
      Navigator.push(context, CupertinoPageRoute(builder: (_) => LegalDocumentScreen(doc: doc)));
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final bool last;
  const _Feature({required this.icon, required this.color, required this.title, required this.body, this.last = false});

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
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 1),
                Text(body, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary, height: 1.3)),
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
  const _PlanCard({required this.title, required this.price, required this.per, this.badge, required this.selected, required this.onTap});

  static const _p = Color(0xFF5856D6);

  @override
  Widget build(BuildContext context) {
    return DSPressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: selected ? _p.withValues(alpha: AppTheme.isDark ? 0.2 : 0.08) : AppTheme.surfaceColor,
          borderRadius: DS.squircle(DS.rLg),
          border: Border.all(color: selected ? _p : AppTheme.glassBorder, width: selected ? 1.6 : 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const Spacer(),
                if (badge != null) Pill(badge!, color: AppTheme.successColor),
              ],
            ),
            const SizedBox(height: 10),
            Text(price,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: AppTheme.textPrimary)),
            Text(per, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
          ],
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
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
      );
}
