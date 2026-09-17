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
            _HomeTab(onOpenCases: () => _onNav(1), onOpenRecords: () => _onNav(2), onOpenCare: () => _onNav(3)),
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
  final VoidCallback onOpenRecords;
  final VoidCallback onOpenCare;
  const _HomeTab({required this.onOpenCases, required this.onOpenRecords, required this.onOpenCare});

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
  Stream<List<MedicalRecord>>? _records;

  void _ensureStreams(String? uid) {
    if (uid == null || uid == _uid) return;
    _uid = uid;
    _records = _db.watchMedicalRecords(uid);
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
                    SliverToBoxAdapter(
                      child: SlideUpAnimation(
                        delay: const Duration(milliseconds: 120),
                        child: _Toolkit(
                          onOpenCases: widget.onOpenCases,
                          onOpenRecords: widget.onOpenRecords,
                          onOpenCare: widget.onOpenCare,
                        ),
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
                        delay: const Duration(milliseconds: 215),
                        child: _RecentRecords(records: _records, onSeeAll: widget.onOpenRecords),
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
                        child: _ProCard(claims: claims, currency: region.currencyCode),
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
      child: HeroButton(
        label: 'Scan a bill, report or letter',
        icon: CupertinoIcons.camera_viewfinder,
        onTap: () => DocumentScanScreen.open(context, trigger: 'home'),
      ),
    );
  }
}

// ── Toolkit ───────────────────────────────────────────────────────────────────

/// Every feature, always visible, each a real entry point. This is the
/// answer to "what can this app do?" on a fresh account, where the money
/// card reads $0 and the case list is empty.
class _Toolkit extends StatelessWidget {
  final VoidCallback onOpenCases;
  final VoidCallback onOpenRecords;
  final VoidCallback onOpenCare;
  const _Toolkit({required this.onOpenCases, required this.onOpenRecords, required this.onOpenCare});

  @override
  Widget build(BuildContext context) {
    void go(String route) => Navigator.pushNamed(context, route);
    final tools = <_Tool>[
      _Tool(CupertinoIcons.doc_text_viewfinder, const Color(0xFF007AFF), 'Bill audit',
          'Find overcharges', () => DocumentScanScreen.open(context, trigger: 'toolkit_bill')),
      _Tool(CupertinoIcons.envelope_open_fill, const Color(0xFF5856D6), 'Appeals',
          'Fight a denial', onOpenCases),
      _Tool(CupertinoIcons.lab_flask_solid, const Color(0xFF32ADE6), 'Lab results',
          'Decoded, with trends', onOpenRecords),
      _Tool(CupertinoIcons.waveform, const Color(0xFF34C759), 'Assistant',
          'Ask about your health', () => go(AppRouter.aiChat)),
      _Tool(CupertinoIcons.capsule_fill, const Color(0xFFAF52DE), 'Medications',
          'Reminders & streaks', () => go(AppRouter.medications)),
      _Tool(CupertinoIcons.shield_lefthalf_fill, const Color(0xFFFF9500), 'Coverage',
          'Deductible & policies', () => go(AppRouter.insurance)),
      _Tool(CupertinoIcons.calendar_badge_plus, const Color(0xFFFF2D55), 'Deadlines',
          'Appeal & dispute dates', () => go(AppRouter.deadlines)),
      _Tool(CupertinoIcons.pencil_ellipsis_rectangle, const Color(0xFF30B0C7), 'Journal',
          'Symptoms over time', () => go(AppRouter.symptomJournal)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSSectionLabel('EVERYTHING CLINIX DOES'),
          LayoutBuilder(builder: (context, c) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final cellH = 32 + 8 + (13.5 * 1.2 + 11.5 * 1.25) * scale + 22;
            final cellW = (c.maxWidth - 10) / 2;
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: cellW / cellH,
              children: [for (final t in tools) _ToolTile(t)],
            );
          }),
          const SizedBox(height: 10),
          // Two rows that answer "how does it actually do that?" — the
          // question every new user asks before they trust a scan.
          InsetCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ExplainRow(
                  icon: CupertinoIcons.doc_text_search,
                  color: AppTheme.warningColor,
                  title: 'How bills & claims are audited',
                  subtitle: '7 steps · rules, Medicare rates, your policy',
                  onTap: () => Navigator.pushNamed(context, AppRouter.howItWorks, arguments: 0),
                ),
                Divider(height: 1, indent: 58, color: AppTheme.dividerColor),
                _ExplainRow(
                  icon: CupertinoIcons.lab_flask_solid,
                  color: AppTheme.infoColor,
                  title: 'How lab reports are analysed',
                  subtitle: '6 steps · ranges, trends, plain English',
                  onTap: () => Navigator.pushNamed(context, AppRouter.howItWorks, arguments: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplainRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ExplainRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DSPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(
          children: [
            IconBadge(icon, color: color, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 15, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _Tool {
  final IconData icon;
  final Color color;
  final String title;
  final String blurb;
  final VoidCallback onTap;
  const _Tool(this.icon, this.color, this.title, this.blurb, this.onTap);
}

class _ToolTile extends StatelessWidget {
  final _Tool t;
  const _ToolTile(this.t);

  @override
  Widget build(BuildContext context) {
    return DSPressable(
      onTap: t.onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: DS.squircle(DS.rMd),
          border: Border.all(color: AppTheme.glassBorder, width: 0.8),
          boxShadow: DS.softShadow(y: 2, blur: 10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: t.color, borderRadius: DS.squircle(9)),
              child: Icon(t.icon, size: 17, color: Colors.white),
            ),
            const Spacer(),
            Text(t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppTheme.textPrimary)),
            Text(t.blurb,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Recent records ────────────────────────────────────────────────────────────

/// Latest scanned reports with their flag count, so a lab result you just
/// added is one tap away instead of buried in the vault.
class _RecentRecords extends StatelessWidget {
  final Stream<List<MedicalRecord>>? records;
  final VoidCallback onSeeAll;
  const _RecentRecords({required this.records, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MedicalRecord>>(
      stream: records,
      builder: (context, snap) {
        final all = snap.data ?? const <MedicalRecord>[];
        if (all.isEmpty) return const SizedBox.shrink();
        final recent = [...all]..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DSSectionLabel(
                'RECENT RECORDS',
                trailing: GestureDetector(
                  onTap: onSeeAll,
                  child: Text('See all',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                ),
              ),
              InsetCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < recent.length && i < 3; i++) ...[
                      if (i > 0) Divider(height: 1, indent: 58, color: AppTheme.dividerColor),
                      _RecordRow(record: recent[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecordRow extends StatelessWidget {
  final MedicalRecord record;
  const _RecordRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final lab = record.isLab;
    final flagged = record.abnormalCount;
    final color = lab ? AppTheme.infoColor : AppTheme.textSecondary;
    return DSPressable(
      onTap: () => Navigator.pushNamed(context, AppRouter.recordDetail, arguments: record),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(
          children: [
            IconBadge(lab ? CupertinoIcons.lab_flask_solid : CupertinoIcons.doc_text_fill,
                color: color, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.title.isEmpty ? 'Medical record' : record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  Text(
                    lab
                        ? (record.labMarkers.isEmpty
                            ? 'Lab report'
                            : flagged == 0
                                ? '${record.labMarkers.length} markers · all in range'
                                : '${record.labMarkers.length} markers · $flagged flagged')
                        : record.recordType[0].toUpperCase() + record.recordType.substring(1),
                    style: TextStyle(
                        fontSize: 12,
                        color: flagged > 0 ? AppTheme.warningColor : AppTheme.textSecondary,
                        fontWeight: flagged > 0 ? FontWeight.w600 : FontWeight.w400),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 15, color: AppTheme.textTertiary),
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
          DSSectionLabel(
            'HOW CLINIX WORKS',
            trailing: GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRouter.howItWorks),
              child: Text('Every step',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
            ),
          ),
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

/// Pro card on Home. When the user has disputable findings it leads with
/// their own number — the one argument that is both true and theirs; with no
/// data it states the free allowance honestly instead of a vague upsell.
class _ProCard extends StatelessWidget {
  final List<InsuranceClaim> claims;
  final String currency;
  const _ProCard({required this.claims, required this.currency});

  @override
  Widget build(BuildContext context) {
    final ent = context.watch<EntitlementService>();
    if (ent.isPro) return const SizedBox.shrink();
    final open = claims.where((c) => !c.isClosed);
    final disputable = open.fold<double>(0, (n, c) => n + c.potentialSaving);
    final hasMoney = disputable > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: InsetCard(
        onTap: () {
          Analytics.paywallShown(hasMoney ? 'home_card_money' : 'home_card');
          Navigator.pushNamed(context, AppRouter.paywall);
        },
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            IconBadge(
              hasMoney ? CupertinoIcons.money_dollar_circle_fill : CupertinoIcons.sparkles,
              color: hasMoney ? AppTheme.successColor : AppTheme.primaryColor,
              size: 42,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasMoney
                        ? '${formatMoney(disputable, currency)} not yet disputed'
                        : 'Clinix Pro',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasMoney
                        ? 'Pro drafts the dispute letter for every finding.'
                        : 'Unlimited audits, letters, reports and family cases.',
                    maxLines: 2,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(16)),
              child: const Text('Go Pro',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
