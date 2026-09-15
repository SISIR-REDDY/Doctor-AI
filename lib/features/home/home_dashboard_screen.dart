import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/insurance_regions.dart';
import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../core/providers/theme_controller.dart';
import '../../models/advocate_models.dart';
import '../../models/patient_models.dart';
import '../../services/analytics_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';
import '../care/care_hub_screen.dart';
import '../claims/claims_screen.dart';
import '../profile/health_profile_screen.dart';
import '../records/records_vault_screen.dart';
import '../scan/document_scan_screen.dart';

/// App shell: Home · Cases · Records · Care · Profile behind a floating
/// glass tab bar. Content scrolls under the bar (`extendBody`).
class HomeDashboardScreen extends StatefulWidget {
  /// When true (fresh onboarding), the scan flow opens on first frame.
  final bool scanFirst;
  const HomeDashboardScreen({super.key, this.scanFirst = false});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthDataProvider>().loadProfile();
      if (widget.scanFirst && mounted) {
        DocumentScanScreen.open(context, trigger: 'onboarding');
      }
    });
  }

  void _onNav(int i) => setState(() => _navIndex = i);

  /// Tabs scroll beneath the floating glass bar; extend the bottom padding so
  /// their lists, FABs and safe areas clear it.
  Widget _underTabBar(BuildContext context, Widget child) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        padding: mq.padding.copyWith(bottom: mq.padding.bottom + GlassTabBar.height + 20),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Persistent tabs live in an IndexedStack and read global theme tokens,
    // so depend on the theme controller + OS brightness explicitly and keep
    // the children non-const so they rebuild on a light/dark toggle.
    context.watch<ThemeController>();
    MediaQuery.platformBrightnessOf(context);
    return PopScope(
      canPop: _navIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _navIndex = 0);
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        extendBody: true,
        body: IndexedStack(
          index: _navIndex,
          children: [
            _HomeTab(onOpenCases: () => _onNav(1), onOpenCare: () => _onNav(3)),
            _underTabBar(context, ClaimsScreen(embedded: true)),
            _underTabBar(context, RecordsVaultScreen()),
            _underTabBar(context, CareHubScreen()),
            _underTabBar(context, HealthProfileScreen()),
          ],
        ),
        bottomNavigationBar: GlassTabBar(
          selectedIndex: _navIndex,
          onSelect: _onNav,
          tabs: const [
            GlassTab(icon: CupertinoIcons.house, activeIcon: CupertinoIcons.house_fill, label: 'Home'),
            GlassTab(icon: CupertinoIcons.briefcase, activeIcon: CupertinoIcons.briefcase_fill, label: 'Cases'),
            GlassTab(icon: CupertinoIcons.folder, activeIcon: CupertinoIcons.folder_fill, label: 'Records'),
            GlassTab(icon: CupertinoIcons.heart, activeIcon: CupertinoIcons.heart_fill, label: 'Care'),
            GlassTab(icon: CupertinoIcons.person, activeIcon: CupertinoIcons.person_fill, label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ── Home tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  final VoidCallback onOpenCases;
  final VoidCallback onOpenCare;
  const _HomeTab({required this.onOpenCases, required this.onOpenCare});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _db = FirestoreService();
  String? _uid;
  Stream<List<InsuranceClaim>>? _claims;
  Stream<List<CaseDeadline>>? _deadlines;
  Stream<List<Medication>>? _meds;
  Stream<List<HealthReminder>>? _reminders;

  void _ensureStreams(String? uid) {
    if (uid == null || uid == _uid) return;
    _uid = uid;
    _claims = _db.watchClaims(uid);
    _deadlines = _db.watchDeadlines(uid);
    _meds = _db.watchMedications(uid);
    _reminders = _db.watchReminders(uid);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthDataProvider>();
    _ensureStreams(provider.uid);
    final profile = provider.profile;
    final region = regionByCode(profile?.country);

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.screenGradient),
      child: SafeArea(
        bottom: false,
        child: StreamBuilder<List<InsuranceClaim>>(
          stream: _claims,
          builder: (context, claimSnap) {
            final claims = claimSnap.data ?? const <InsuranceClaim>[];
            return StreamBuilder<List<CaseDeadline>>(
              stream: _deadlines,
              builder: (context, dlSnap) {
                final deadlines = (dlSnap.data ?? const <CaseDeadline>[])
                    .where((d) => !d.completed)
                    .toList();
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _Header(
                        name: provider.displayName,
                        alerts: deadlines.where((d) => d.daysLeft <= 14).length,
                        onAvatar: () => Navigator.pushNamed(context, AppRouter.healthProfile),
                        onBell: () => Navigator.pushNamed(context, AppRouter.deadlines),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SlideUpAnimation(
                        delay: const Duration(milliseconds: 40),
                        child: _MoneyCard(
                          claims: claims,
                          currency: region.currencyCode,
                          onTap: widget.onOpenCases,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SlideUpAnimation(
                        delay: const Duration(milliseconds: 90),
                        child: _ScanActions(),
                      ),
                    ),
                    if (deadlines.isNotEmpty || claims.any((c) => !c.isClosed))
                      SliverToBoxAdapter(
                        child: SlideUpAnimation(
                          delay: const Duration(milliseconds: 140),
                          child: _NeedsAttention(
                            deadlines: deadlines,
                            claims: claims,
                            currency: region.currencyCode,
                          ),
                        ),
                      ),
                    if (claims.isEmpty)
                      SliverToBoxAdapter(
                        child: SlideUpAnimation(
                          delay: const Duration(milliseconds: 140),
                          child: _HowItWorks(goals: profile?.goals ?? const []),
                        ),
                      ),
                    if (claims.isNotEmpty)
                      SliverToBoxAdapter(
                        child: SlideUpAnimation(
                          delay: const Duration(milliseconds: 190),
                          child: _CasesStrip(
                            claims: claims,
                            currency: region.currencyCode,
                            onSeeAll: widget.onOpenCases,
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: SlideUpAnimation(
                        delay: const Duration(milliseconds: 240),
                        child: _CareToday(
                          meds: _meds,
                          reminders: _reminders,
                          onOpen: widget.onOpenCare,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SlideUpAnimation(
                        delay: const Duration(milliseconds: 290),
                        child: _ProCard(),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String name;
  final int alerts;
  final VoidCallback onAvatar;
  final VoidCallback onBell;
  const _Header({required this.name, required this.alerts, required this.onAvatar, required this.onBell});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: AppTheme.labelMedium),
                const SizedBox(height: 2),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.headingLarge.copyWith(fontSize: 30, letterSpacing: -1)),
              ],
            ),
          ),
          _RoundButton(
            icon: CupertinoIcons.bell,
            badge: alerts,
            onTap: onBell,
          ),
          const SizedBox(width: 10),
          DSPressable(
            onTap: onAvatar,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: DS.softShadow(y: 4, blur: 12),
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, this.badge = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DSPressable(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.glassBorder, width: 0.8),
              boxShadow: DS.softShadow(y: 3, blur: 10),
            ),
            child: Icon(icon, size: 21, color: AppTheme.textPrimary),
          ),
          if (badge > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.backgroundColor, width: 2),
                ),
                child: Text('$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Money card ────────────────────────────────────────────────────────────────

class _MoneyCard extends StatelessWidget {
  final List<InsuranceClaim> claims;
  final String currency;
  final VoidCallback onTap;
  const _MoneyCard({required this.claims, required this.currency, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final potential = claims.where((c) => !c.isClosed).fold<double>(0, (s, c) => s + c.potentialSaving);
    final recovered = claims.fold<double>(0, (s, c) => s + c.totalRecovered);
    final open = claims.where((c) => !c.isClosed).length;
    final empty = claims.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: DSPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A84FF), Color(0xFF0057D9), Color(0xFF003F9E)],
            ),
            borderRadius: DS.squircle(DS.rXl),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0057D9).withValues(alpha: 0.38),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -40,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.money_dollar_circle_fill,
                          color: Colors.white.withValues(alpha: 0.9), size: 18),
                      const SizedBox(width: 7),
                      Text(empty ? 'YOUR MONEY' : '$open OPEN ${open == 1 ? 'CASE' : 'CASES'}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2)),
                      const Spacer(),
                      Icon(CupertinoIcons.chevron_right, color: Colors.white.withValues(alpha: 0.8), size: 16),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'Potential savings',
                          value: empty ? '—' : formatMoney(potential, currency),
                          foreground: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          label: 'Recovered',
                          value: empty ? '—' : formatMoney(recovered, currency),
                          foreground: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  if (empty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Scan your first bill or letter to see what you could get back.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Scan actions ──────────────────────────────────────────────────────────────

class _ScanActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          // The scanner is universal — bills, denials, lab reports, letters —
          // so the label says so; the onboarding promises all four.
          HeroButton(
            label: 'Scan a bill, report or letter',
            icon: CupertinoIcons.camera_viewfinder,
            onTap: () => DocumentScanScreen.open(context, trigger: 'home'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: CupertinoIcons.chat_bubble_2_fill,
                  color: AppTheme.successColor,
                  label: 'Ask the assistant',
                  onTap: () => Navigator.pushNamed(context, AppRouter.aiChat),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: CupertinoIcons.capsule_fill,
                  color: AppTheme.oncologyColor,
                  label: 'Medications',
                  onTap: () => Navigator.pushNamed(context, AppRouter.medications),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: CupertinoIcons.folder_fill,
                  color: AppTheme.primaryColor,
                  label: 'Records vault',
                  onTap: () => Navigator.pushNamed(context, AppRouter.recordsVault),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: CupertinoIcons.shield_lefthalf_fill,
                  color: AppTheme.warningColor,
                  label: 'My policies',
                  onTap: () => Navigator.pushNamed(context, AppRouter.insurance),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DSPressable(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppTheme.glassBorder, width: 0.8),
          boxShadow: DS.softShadow(y: 3, blur: 10),
        ),
        child: Row(
          children: [
            IconBadge(icon, color: color, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Needs attention ───────────────────────────────────────────────────────────

class _NeedsAttention extends StatelessWidget {
  final List<CaseDeadline> deadlines;
  final List<InsuranceClaim> claims;
  final String currency;
  const _NeedsAttention({required this.deadlines, required this.claims, required this.currency});

  @override
  Widget build(BuildContext context) {
    final soon = deadlines.where((d) => d.daysLeft <= 30).take(3).toList();
    final actionable = claims.where((c) => !c.isClosed).take(soon.isEmpty ? 3 : 2).toList();
    if (soon.isEmpty && actionable.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSSectionLabel('NEEDS ATTENTION'),
          InsetCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final d in soon)
                  InsetRow(
                    icon: d.isOverdue ? CupertinoIcons.exclamationmark_circle_fill : CupertinoIcons.clock_fill,
                    iconColor: d.isOverdue
                        ? AppTheme.dangerColor
                        : d.daysLeft <= 7
                            ? AppTheme.warningColor
                            : AppTheme.primaryColor,
                    title: d.title,
                    subtitle: d.caseTitle,
                    value: d.isOverdue
                        ? 'Overdue'
                        : d.daysLeft == 0
                            ? 'Today'
                            : '${d.daysLeft}d left',
                    onTap: () => Navigator.pushNamed(context, AppRouter.deadlines),
                  ),
                for (final c in actionable)
                  InsetRow(
                    icon: c.hasDenial ? CupertinoIcons.xmark_shield_fill : CupertinoIcons.doc_text_fill,
                    iconColor: c.hasDenial ? AppTheme.warningColor : AppTheme.primaryColor,
                    title: c.nextAction,
                    subtitle: c.title.isNotEmpty ? c.title : (c.hospitalName.isNotEmpty ? c.hospitalName : c.insurer),
                    value: c.potentialSaving > 0 ? formatMoney(c.potentialSaving, c.currencyCode.isEmpty ? currency : c.currencyCode) : null,
                    onTap: () => Navigator.pushNamed(context, AppRouter.claimDetail, arguments: c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── How it works (empty state) ────────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  final List<String> goals;
  const _HowItWorks({required this.goals});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (CupertinoIcons.camera_fill, AppTheme.primaryColor, 'Scan', 'A bill, an insurer statement or a denial letter — photo or PDF.'),
      (CupertinoIcons.doc_text_search, AppTheme.warningColor, 'Audit', 'Every line is checked for errors and compared with fair prices.'),
      (CupertinoIcons.paperplane_fill, AppTheme.successColor, 'Act', 'Send the dispute or appeal we draft, track deadlines, record what you got back.'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSSectionLabel('HOW CLINIX WORKS'),
          InsetCard(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconBadge(steps[i].$1, color: steps[i].$2, size: 38),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${i + 1}. ${steps[i].$3}',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                              const SizedBox(height: 2),
                              Text(steps[i].$4,
                                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary, height: 1.35)),
                            ],
                          ),
                        ),
                      ],
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

// ── Cases strip ───────────────────────────────────────────────────────────────

class _CasesStrip extends StatelessWidget {
  final List<InsuranceClaim> claims;
  final String currency;
  final VoidCallback onSeeAll;
  const _CasesStrip({required this.claims, required this.currency, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final items = claims.take(6).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DSSectionLabel(
              'YOUR CASES',
              trailing: GestureDetector(
                onTap: onSeeAll,
                child: Text('See all',
                    style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _CaseMiniCard(claim: items[i], currency: currency),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseMiniCard extends StatelessWidget {
  final InsuranceClaim claim;
  final String currency;
  const _CaseMiniCard({required this.claim, required this.currency});

  @override
  Widget build(BuildContext context) {
    final cur = claim.currencyCode.isEmpty ? currency : claim.currencyCode;
    final title = claim.title.isNotEmpty
        ? claim.title
        : claim.hospitalName.isNotEmpty
            ? claim.hospitalName
            : claim.insurer.isNotEmpty
                ? claim.insurer
                : 'Untitled case';
    final color = claim.isClosed
        ? AppTheme.textTertiary
        : claim.hasDenial
            ? AppTheme.warningColor
            : AppTheme.primaryColor;
    return DSPressable(
      onTap: () => Navigator.pushNamed(context, AppRouter.claimDetail, arguments: claim),
      child: Container(
        width: 228,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: DS.squircle(DS.rLg),
          border: Border.all(color: AppTheme.glassBorder, width: 0.8),
          boxShadow: DS.softShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(claim.hasDenial ? CupertinoIcons.xmark_shield_fill : CupertinoIcons.doc_text_fill,
                    color: color, size: 30),
                const Spacer(),
                Pill(claim.isClosed ? OutcomeStatus.label(claim.outcomeStatus) : 'Open', color: color),
              ],
            ),
            const Spacer(),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(
              claim.potentialSaving > 0
                  ? 'Up to ${formatMoney(claim.potentialSaving, cur)} to recover'
                  : claim.effectiveAmount > 0
                      ? formatMoney(claim.effectiveAmount, cur)
                      : claim.nextAction,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall.copyWith(
                  color: claim.potentialSaving > 0 ? AppTheme.successColor : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Care today ────────────────────────────────────────────────────────────────

class _CareToday extends StatelessWidget {
  final Stream<List<Medication>>? meds;
  final Stream<List<HealthReminder>>? reminders;
  final VoidCallback onOpen;
  const _CareToday({required this.meds, required this.reminders, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Medication>>(
      stream: meds,
      builder: (context, medSnap) {
        final doses = (medSnap.data ?? const <Medication>[])
            .where((m) => m.isActive)
            .fold<int>(0, (s, m) => s + m.reminderTimes.length);
        return StreamBuilder<List<HealthReminder>>(
          stream: reminders,
          builder: (context, remSnap) {
            final now = DateTime.now();
            final upcoming = (remSnap.data ?? const <HealthReminder>[])
                .where((r) => !r.completed && r.dateTime.isAfter(now))
                .toList()
              ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
            final next = upcoming.isEmpty ? null : upcoming.first;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DSSectionLabel('CARE'),
                  InsetCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        InsetRow(
                          icon: CupertinoIcons.capsule_fill,
                          iconColor: AppTheme.successColor,
                          title: 'Medications',
                          subtitle: doses == 0 ? 'No doses scheduled today' : '$doses ${doses == 1 ? 'dose' : 'doses'} scheduled today',
                          onTap: onOpen,
                        ),
                        InsetRow(
                          icon: CupertinoIcons.calendar,
                          iconColor: AppTheme.secondaryColor,
                          title: next == null ? 'Appointments & reminders' : next.title,
                          subtitle: next == null ? 'Nothing upcoming' : _relative(next.dateTime),
                          onTap: () => Navigator.pushNamed(context, AppRouter.reminders),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _relative(DateTime t) {
    final d = t.difference(DateTime.now());
    if (d.inDays >= 1) return 'In ${d.inDays} ${d.inDays == 1 ? 'day' : 'days'}';
    if (d.inHours >= 1) return 'In ${d.inHours} h';
    return 'In ${d.inMinutes} min';
  }
}

// ── Pro upsell ────────────────────────────────────────────────────────────────

class _ProCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ent = context.watch<EntitlementService>();
    if (ent.isPro) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: InsetCard(
        onTap: () {
          Analytics.paywallShown('home_card');
          Navigator.pushNamed(context, AppRouter.paywall);
        },
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C2E), Color(0xFF2B2140)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Row(
          children: [
            const IconBadge(CupertinoIcons.sparkles, color: Color(0xFFFFD60A), size: 42, filled: true),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Clinix Pro',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Unlimited audits, appeals & deadline tracking.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3)),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }
}
