import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../core/providers/theme_controller.dart';
import '../../features/insurance/insurance_screen.dart';
import '../../features/profile/health_profile_screen.dart';
import '../../features/records/records_vault_screen.dart';
import '../../features/symptom_journal/symptom_journal_screen.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_theme.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _navIndex = 0;

  void _go(String route) => Navigator.pushNamed(context, route);

  void _onNav(int index) => setState(() => _navIndex = index);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthDataProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Depend on the theme controller AND platform brightness so the whole tab
    // tree (kept alive in the IndexedStack) rebuilds when the user toggles
    // light/dark or the OS appearance changes — otherwise these persistent
    // screens keep their old colors. The children below are intentionally NOT
    // const so they actually rebuild on that change.
    context.watch<ThemeController>();
    MediaQuery.platformBrightnessOf(context);
    return PopScope(
      canPop: _navIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _navIndex = 0);
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: IndexedStack(
          index: _navIndex,
          children: [
            _HomeTab(
              onProfile: () => _onNav(4),
              onAiChat: () => _go(AppRouter.aiChat),
              onSymptomJournal: () => _onNav(1),
              onHealthProfile: () => _onNav(4),
              onMedications: () => _go(AppRouter.medications),
              onRecords: () => _onNav(2),
              onInsurance: () => _onNav(3),
              onNewClaim: () => _go(AppRouter.newClaim),
              onClaims: () => _go(AppRouter.claims),
              onReminders: () => _go(AppRouter.reminders),
            ),
            SymptomJournalScreen(),
            RecordsVaultScreen(),
            InsuranceScreen(),
            HealthProfileScreen(),
          ],
        ),
        floatingActionButton: _navIndex == 0
            ? _GlossyFab(onTap: () => _go(AppRouter.aiChat))
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: GlossyBottomNav(
          selectedIndex: _navIndex,
          onSelect: _onNav,
          destinations: const [
            GlossyNavDestination(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
            ),
            GlossyNavDestination(
              icon: Icons.edit_note_outlined,
              activeIcon: Icons.edit_note_rounded,
              label: 'Journal',
            ),
            GlossyNavDestination(
              icon: Icons.folder_outlined,
              activeIcon: Icons.folder_rounded,
              label: 'Records',
            ),
            GlossyNavDestination(
              icon: Icons.shield_outlined,
              activeIcon: Icons.shield_rounded,
              label: 'Insurance',
            ),
            GlossyNavDestination(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onAiChat;
  final VoidCallback onSymptomJournal;
  final VoidCallback onHealthProfile;
  final VoidCallback onMedications;
  final VoidCallback onRecords;
  final VoidCallback onInsurance;
  final VoidCallback onNewClaim;
  final VoidCallback onClaims;
  final VoidCallback onReminders;

  const _HomeTab({
    required this.onProfile,
    required this.onAiChat,
    required this.onSymptomJournal,
    required this.onHealthProfile,
    required this.onMedications,
    required this.onRecords,
    required this.onInsurance,
    required this.onNewClaim,
    required this.onClaims,
    required this.onReminders,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.isDark
              ? const [Color(0xFF16161E), Color(0xFF101015), Color(0xFF0B0B0F)]
              : const [
                  Color(0xFFD8E8FF),
                  Color(0xFFEAF0FF),
                  Color(0xFFF0F4FB),
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _Header(onProfile: onProfile)),
            SliverToBoxAdapter(
              child: SlideUpAnimation(
                delay: const Duration(milliseconds: 40),
                child: _AiPromptCard(onTap: onAiChat),
              ),
            ),
            SliverToBoxAdapter(
              child: SlideUpAnimation(
                delay: const Duration(milliseconds: 100),
                child: _HealthOverview(onEdit: onHealthProfile),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: SlideUpAnimation(
                delay: const Duration(milliseconds: 160),
                child: _FeatureSection(
                label: 'AI & DAILY CARE',
                items: [
                  _MenuItem(
                    icon: Icons.psychology_outlined,
                    iconBg: const Color(0xFFCEE5FF),
                    iconColor: AppTheme.primaryColor,
                    title: 'AI Health Assistant',
                    subtitle: 'Describe symptoms — get guidance from Gemini',
                    onTap: onAiChat,
                  ),
                  _MenuItem(
                    icon: Icons.calendar_today_outlined,
                    iconBg: const Color(0xFFE6E0FF),
                    iconColor: AppTheme.secondaryColor,
                    title: 'Symptom Journal',
                    subtitle: 'Log daily symptoms & AI trend analysis',
                    onTap: onSymptomJournal,
                  ),
                  _MenuItem(
                    icon: Icons.notifications_active_outlined,
                    iconBg: const Color(0xFFCBF0DC),
                    iconColor: AppTheme.successColor,
                    title: 'Reminders & Schedule',
                    subtitle: 'Medication doses, vaccinations & appointments',
                    onTap: onReminders,
                  ),
                ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SlideUpAnimation(
                delay: const Duration(milliseconds: 220),
                child: _FeatureSection(
                label: 'YOUR HEALTH DATA',
                items: [
                  _MenuItem(
                    icon: Icons.person_outline_rounded,
                    iconBg: const Color(0xFFCEE5FF),
                    iconColor: AppTheme.primaryColor,
                    title: 'Health Profile',
                    subtitle: 'Allergies, food allergies, past diseases, contacts',
                    onTap: onHealthProfile,
                  ),
                  _MenuItem(
                    icon: Icons.medication_outlined,
                    iconBg: const Color(0xFFCBF0DC),
                    iconColor: AppTheme.successColor,
                    title: 'Medications',
                    subtitle: 'Active & past medicines, dosage, doctor notes',
                    onTap: onMedications,
                  ),
                ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SlideUpAnimation(
                delay: const Duration(milliseconds: 280),
                child: _FeatureSection(
                label: 'REPORTS & DOCUMENTS',
                items: [
                  _MenuItem(
                    icon: Icons.document_scanner_outlined,
                    iconBg: const Color(0xFFFFE8C8),
                    iconColor: AppTheme.warningColor,
                    title: 'Scan & Analyze Reports',
                    subtitle: 'Camera or gallery — Gemini summarizes results',
                    onTap: onRecords,
                  ),
                  _MenuItem(
                    icon: Icons.folder_open_outlined,
                    iconBg: const Color(0xFFC8EDFF),
                    iconColor: AppTheme.infoColor,
                    title: 'Records Vault',
                    subtitle: 'Prescriptions, lab reports & medical files',
                    onTap: onRecords,
                  ),
                ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SlideUpAnimation(
                delay: const Duration(milliseconds: 340),
                child: _FeatureSection(
                label: 'INSURANCE & CLAIMS',
                items: [
                  _MenuItem(
                    icon: Icons.shield_outlined,
                    iconBg: const Color(0xFFFFE8C8),
                    iconColor: AppTheme.warningColor,
                    title: 'Insurance Policies',
                    subtitle: 'Health & term insurance details in one place',
                    onTap: onInsurance,
                  ),
                  _MenuItem(
                    icon: Icons.add_chart_outlined,
                    iconBg: const Color(0xFFCEE5FF),
                    iconColor: AppTheme.primaryColor,
                    title: 'File a Claim',
                    subtitle: 'AI prepares your claim report for submission',
                    onTap: onNewClaim,
                  ),
                  _MenuItem(
                    icon: Icons.receipt_long_outlined,
                    iconBg: const Color(0xFFEEEEF5),
                    iconColor: AppTheme.textSecondary,
                    title: 'My Claims',
                    subtitle: 'Track status — fight rejections with AI legal help',
                    onTap: onClaims,
                    showDivider: false,
                  ),
                ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _GlossyFab extends StatelessWidget {
  final VoidCallback onTap;

  const _GlossyFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, right: 4),
      decoration: BoxDecoration(
        gradient: AppTheme.fabGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Ask AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onProfile;

  const _Header({required this.onProfile});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthDataProvider>();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final initial = provider.displayName.isNotEmpty
        ? provider.displayName[0].toUpperCase()
        : 'U';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: AppTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  provider.displayName,
                  style: AppTheme.headingLarge,
                ),
              ],
            ),
          ),
          _GlossyIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () {},
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onProfile,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI prompt ─────────────────────────────────────────────────────────────────

class _AiPromptCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AiPromptCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: GlossyCard(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(18),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What\'s bothering you?',
                    style: AppTheme.headingSmall.copyWith(
                      color: Colors.white,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chat or speak — voice powered by Deepgram',
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Health overview grid ──────────────────────────────────────────────────────

class _HealthOverview extends StatelessWidget {
  final VoidCallback onEdit;

  const _HealthOverview({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<HealthDataProvider>().profile;
    final allergyCount = profile?.allAllergies.length ?? 0;
    final conditionCount =
        (profile?.pastDiseases.length ?? 0) +
        (profile?.chronicConditions.length ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Health at a glance', style: AppTheme.headingSmall),
              const Spacer(),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Blood',
                  value: profile?.bloodGroup.isNotEmpty == true
                      ? profile!.bloodGroup
                      : '—',
                  icon: Icons.water_drop_outlined,
                  iconBg: const Color(0xFFFFD8D6),
                  iconColor: AppTheme.dangerColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'BMI',
                  value: profile != null && profile.bmi > 0
                      ? profile.bmi.toStringAsFixed(1)
                      : '—',
                  icon: Icons.monitor_weight_outlined,
                  iconBg: const Color(0xFFCEE5FF),
                  iconColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Allergies',
                  value: '$allergyCount',
                  icon: Icons.warning_amber_outlined,
                  iconBg: const Color(0xFFFFE8C8),
                  iconColor: AppTheme.warningColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Conditions',
                  value: '$conditionCount',
                  icon: Icons.history_edu_outlined,
                  iconBg: const Color(0xFFE6E0FF),
                  iconColor: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlossyPanel(
      padding: const EdgeInsets.all(14),
      radius: 14,
      enableBlur: true,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.labelSmall),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
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

// ── Feature sections ──────────────────────────────────────────────────────────

class _FeatureSection extends StatelessWidget {
  final String label;
  final List<_MenuItem> items;

  const _FeatureSection({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(label, style: AppTheme.sectionLabel),
          ),
          GlossyPanel(
            radius: 20,
            enableBlur: true,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  items[i].copyWith(
                    showDivider: i < items.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlossyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlossyIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Icon(icon, size: 22, color: AppTheme.textSecondary),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  const _MenuItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  _MenuItem copyWith({bool? showDivider}) {
    return _MenuItem(
      icon: icon,
      iconBg: iconBg,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      showDivider: showDivider ?? this.showDivider,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: showDivider
                ? null
                : const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: AppTheme.bodySmall.copyWith(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textTertiary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 72,
            color: AppTheme.dividerColor.withValues(alpha: 0.8),
          ),
      ],
    );
  }
}
