import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../theme/app_theme.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthDataProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: IndexedStack(
        index: _tab,
        children: const [
          _HomeTab(),
          _PlaceholderTab(label: 'Records'),
          _PlaceholderTab(label: 'Insurance'),
          _PlaceholderTab(label: 'Profile'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          if (i == 1) {
            Navigator.pushNamed(context, AppRouter.recordsVault);
            return;
          }
          if (i == 2) {
            Navigator.pushNamed(context, AppRouter.insurance);
            return;
          }
          if (i == 3) {
            Navigator.pushNamed(context, AppRouter.healthProfile);
            return;
          }
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder_rounded),
              label: 'Records'),
          NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield_rounded),
              label: 'Insurance'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ],
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.12),
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _GreetingHeader()),
        SliverToBoxAdapter(child: _HeroCard()),
        SliverToBoxAdapter(child: _QuickActionsGrid()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ── Greeting Header ───────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthDataProvider>();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.xl, AppTheme.xl + 16, AppTheme.xl, AppTheme.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: AppTheme.bodyMedium
                      .copyWith(color: AppTheme.textSecondary),
                ),
                Text(
                  provider.displayName,
                  style: AppTheme.headingLarge.copyWith(height: 1.1),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, AppRouter.healthProfile),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              child: Text(
                provider.displayName.isNotEmpty
                    ? provider.displayName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
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

// ── Hero Card — AI Chat ───────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      gradient: AppTheme.primaryGradient,
      margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.xl, vertical: AppTheme.sm),
      padding: const EdgeInsets.all(AppTheme.xl),
      onTap: () => Navigator.pushNamed(context, AppRouter.aiChat),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'AI HEALTH ASSISTANT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.md),
                const Text(
                  'How are you\nfeeling today?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppTheme.sm),
                const Text(
                  'Describe your symptoms and get\nAI-powered guidance instantly.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppTheme.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.lg, vertical: AppTheme.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppTheme.mediumRadius,
                  ),
                  child: const Text(
                    'Start chat →',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.lg),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }
}

// ── Quick Actions Grid ────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action(
        icon: Icons.format_list_bulleted_rounded,
        label: 'Symptom\nJournal',
        color: const Color(0xFF7C3AED),
        route: AppRouter.symptomJournal,
      ),
      _Action(
        icon: Icons.medication_rounded,
        label: 'Medication\nTracker',
        color: AppTheme.surgeryColor,
        route: AppRouter.medications,
      ),
      _Action(
        icon: Icons.document_scanner_rounded,
        label: 'Scan\nReport',
        color: AppTheme.secondaryColor,
        route: AppRouter.recordsVault,
      ),
      _Action(
        icon: Icons.verified_user_rounded,
        label: 'Insurance\nPolicies',
        color: AppTheme.warningColor,
        route: AppRouter.insurance,
      ),
      _Action(
        icon: Icons.receipt_long_rounded,
        label: 'File a\nClaim',
        color: AppTheme.infoColor,
        route: AppRouter.claims,
      ),
      _Action(
        icon: Icons.gavel_rounded,
        label: 'Fight\nRejection',
        color: AppTheme.dangerColor,
        route: AppRouter.claims,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.xl, vertical: AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions',
              style: AppTheme.headingSmall.copyWith(fontSize: 17)),
          const SizedBox(height: AppTheme.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: actions.length,
            itemBuilder: (ctx, i) => _ActionTile(action: actions[i]),
          ),
        ],
      ),
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });
}

class _ActionTile extends StatelessWidget {
  final _Action action;
  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, action.route),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(color: AppTheme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: AppTheme.labelMedium.copyWith(
                fontSize: 11,
                color: AppTheme.textPrimary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Placeholder Tab ───────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label));
  }
}
