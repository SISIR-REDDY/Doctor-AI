import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/insurance_regions.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';

/// Bump when the questions change so existing users are re-asked.
const int kOnboardingVersion = 2;

/// Goal ids stored on the profile; drive Home ordering + analytics.
class UserGoal {
  static const billError = 'bill_error';
  static const denial = 'denial';
  static const coverage = 'coverage';
  static const records = 'records';
  static const care = 'care';
}

/// Post-sign-in onboarding: country → goals → about you → first scan.
///
/// Deliberately short: health details (allergies, conditions, contacts) are
/// collected later, in context, not before the user has seen any value.
class OnboardingScreen extends StatefulWidget {
  /// Existing profile (legacy users) to prefill from.
  final PatientProfile? existing;

  /// Called after the profile is saved. [scanFirst] is true when the user
  /// chose "Scan a document" as their first action.
  final void Function({required bool scanFirst}) onComplete;

  const OnboardingScreen({super.key, this.existing, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _step = 0;
  bool _saving = false;

  String _country = '';
  final Set<String> _goals = {};
  bool _family = false;
  late final TextEditingController _first;
  late final TextEditingController _last;

  static const _steps = 4;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final existing = widget.existing;
    final parts = (user?.displayName ?? '').trim().split(RegExp(r'\s+'));
    _first = TextEditingController(
        text: existing?.firstName.isNotEmpty == true
            ? existing!.firstName
            : (parts.isNotEmpty ? parts.first : ''));
    _last = TextEditingController(
        text: existing?.lastName.isNotEmpty == true
            ? existing!.lastName
            : (parts.length > 1 ? parts.sublist(1).join(' ') : ''));
    _country = existing?.country ?? '';
    _goals.addAll(existing?.goals ?? const []);
    _family = existing?.familyMode ?? false;
    Analytics.onboardingStep('start');
  }

  @override
  void dispose() {
    _page.dispose();
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
        0 => _country.isNotEmpty,
        1 => _goals.isNotEmpty,
        2 => _first.text.trim().isNotEmpty,
        _ => true,
      };

  void _go(int step) {
    setState(() => _step = step);
    _page.animateToPage(step,
        duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  Future<void> _next() async {
    HapticFeedback.lightImpact();
    if (_step < _steps - 1) {
      Analytics.onboardingStep('step_${_step + 1}');
      _go(_step + 1);
      return;
    }
  }

  Future<void> _finish({required bool scanFirst}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _saving) return;
    setState(() => _saving = true);
    try {
      final base = widget.existing ?? PatientProfile(id: user.uid, email: user.email ?? '');
      final profile = base.copyWith(
        id: user.uid,
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        email: user.email ?? base.email,
        country: _country,
        goals: _goals.toList(),
        familyMode: _family,
        onboardingVersion: kOnboardingVersion,
        updatedAt: DateTime.now(),
      );
      await context.read<HealthDataProvider>().saveProfile(profile);
      Analytics.onboardingComplete(_country);
      Analytics.setUser(user.uid, region: _country);
      if (mounted) widget.onComplete(scanFirst: scanFirst);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            FlowTopBar(
              onBack: _step == 0 ? null : () => _go(_step - 1),
              progress: (_step + 1) / _steps,
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepScaffold(
                    title: 'Where are you insured?',
                    subtitle:
                        'Rules, deadlines and fair prices differ by country. You can change this later.',
                    child: _CountryStep(
                      selected: _country,
                      onSelect: (c) => setState(() => _country = c),
                    ),
                  ),
                  _StepScaffold(
                    title: 'What brought you here?',
                    subtitle: 'Pick everything that applies — we’ll set up your home screen around it.',
                    child: _GoalsStep(
                      selected: _goals,
                      onToggle: (g) => setState(() {
                        if (!_goals.remove(g)) _goals.add(g);
                      }),
                    ),
                  ),
                  _StepScaffold(
                    title: 'About you',
                    subtitle: 'Your name appears on the letters Clinix drafts for you.',
                    child: _AboutStep(
                      first: _first,
                      last: _last,
                      family: _family,
                      onFamilyChanged: (v) => setState(() => _family = v),
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  _ReadyStep(
                    saving: _saving,
                    goals: _goals,
                    onScan: () => _finish(scanFirst: true),
                    onExplore: () => _finish(scanFirst: false),
                  ),
                ],
              ),
            ),
            if (_step < _steps - 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                child: HeroButton(
                  label: 'Continue',
                  onTap: _canContinue ? _next : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Step scaffold ─────────────────────────────────────────────────────────────

class _StepScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _StepScaffold({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                  height: 1.1,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(fontSize: 15, height: 1.4, color: AppTheme.textSecondary)),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

// ── Step 1: country ───────────────────────────────────────────────────────────

class _CountryStep extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _CountryStep({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final r in kInsuranceRegions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChoiceCard(
              leading: Text(r.flag, style: const TextStyle(fontSize: 26)),
              title: r.name,
              subtitle: '${r.currencyCode} · ${r.regulator.split(' (').first}',
              selected: selected == r.code,
              onTap: () => onSelect(r.code),
            ),
          ),
      ],
    );
  }
}

// ── Step 2: goals ─────────────────────────────────────────────────────────────

class _GoalsStep extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _GoalsStep({required this.selected, required this.onToggle});

  static const _items = [
    (UserGoal.billError, CupertinoIcons.doc_text_search, 'A medical bill looks wrong', 'Find errors and overcharges, dispute them'),
    (UserGoal.denial, CupertinoIcons.xmark_shield_fill, 'A claim or approval was denied', 'Understand why and appeal it'),
    (UserGoal.coverage, CupertinoIcons.creditcard_fill, 'Understand what my insurance covers', 'Deductibles, limits, what you’ll pay'),
    (UserGoal.records, CupertinoIcons.folder_fill, 'Keep medical records organised', 'Lab results, prescriptions, reports'),
    (UserGoal.care, CupertinoIcons.alarm_fill, 'Track medications & appointments', 'Reminders that actually fire'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppTheme.dangerColor,
      AppTheme.warningColor,
      AppTheme.primaryColor,
      AppTheme.infoColor,
      AppTheme.successColor,
    ];
    return Column(
      children: [
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChoiceCard(
              multi: true,
              leading: IconBadge(_items[i].$2, color: colors[i], size: 40),
              title: _items[i].$3,
              subtitle: _items[i].$4,
              selected: selected.contains(_items[i].$1),
              onTap: () => onToggle(_items[i].$1),
            ),
          ),
      ],
    );
  }
}

// ── Step 3: about you ─────────────────────────────────────────────────────────

class _AboutStep extends StatelessWidget {
  final TextEditingController first;
  final TextEditingController last;
  final bool family;
  final ValueChanged<bool> onFamilyChanged;
  final VoidCallback onChanged;
  const _AboutStep({
    required this.first,
    required this.last,
    required this.family,
    required this.onFamilyChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: first,
                onChanged: (_) => onChanged(),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'First name'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: last,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Last name'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text('Who will you use Clinix for?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        ChoiceCard(
          leading: IconBadge(CupertinoIcons.person_fill, color: AppTheme.primaryColor),
          title: 'Just me',
          selected: !family,
          onTap: () => onFamilyChanged(false),
        ),
        const SizedBox(height: 10),
        ChoiceCard(
          leading: IconBadge(CupertinoIcons.person_2_fill, color: AppTheme.secondaryColor),
          title: 'Me and my family',
          subtitle: 'Bills and claims for dependants too',
          selected: family,
          onTap: () => onFamilyChanged(true),
        ),
      ],
    );
  }
}

// ── Step 4: ready ─────────────────────────────────────────────────────────────

class _ReadyStep extends StatelessWidget {
  final bool saving;
  final Set<String> goals;
  final VoidCallback onScan;
  final VoidCallback onExplore;
  const _ReadyStep({
    required this.saving,
    required this.goals,
    required this.onScan,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    final wantsDenial = goals.contains(UserGoal.denial) && !goals.contains(UserGoal.billError);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: const Icon(CupertinoIcons.camera_viewfinder, color: Colors.white, size: 46),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            wantsDenial ? 'Start with the denial letter.' : 'Start with one document.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.9,
                height: 1.1,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            wantsDenial
                ? 'Photograph the letter and Clinix will explain it, list your rights and prepare the appeal.'
                : 'A bill, an insurance statement or a denial letter — Clinix reads it and tells you what to do next.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15.5, height: 1.45, color: AppTheme.textSecondary),
          ),
          const Spacer(),
          HeroButton(
            label: 'Scan a document',
            icon: CupertinoIcons.camera_fill,
            loading: saving,
            onTap: saving ? null : onScan,
          ),
          const SizedBox(height: 10),
          TonalButton(label: 'Explore the app first', onTap: saving ? null : onExplore),
        ],
      ),
    );
  }
}
