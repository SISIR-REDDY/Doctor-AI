import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/errors/app_error_handler.dart';
import '../core/utils/logout_utils.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import 'doctor_patients_screen.dart';
import 'clinical_notes_screen.dart';
import 'medication_safety_screen.dart';
import 'shift_handoff_screen.dart';
import 'emergency_triage_screen.dart';
import 'ward_rounds_screen.dart';
import '../features/transcription/presentation/transcription_controller.dart';
import '../features/transcription/presentation/transcription_screen.dart';
import 'doctor_profile_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  static const Color _pageBg = Color(0xFFF6F7FB);
  static const Color _card = Colors.white;
  static const Color _ink = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _brandBlue = Color(0xFF2563EB);
  static const Color _brandTeal = Color(0xFF14B8A6);
  static const Color _heroStart = Color(0xFF1F2937);
  static const Color _heroEnd = Color(0xFF1D4ED8);
  static const Color _heroGlow = Color(0xFF60A5FA);

  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final doctorId = _authService.currentUser?.uid;
    if (doctorId == null || doctorId.isEmpty) {
      return;
    }

    try {
      await _firestoreService.getDoctorPatients(doctorId);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
  }

  void _signOut() async {
    await LogoutUtils.performSafeLogout(
      context: context,
      onLogout: () => _authService.signOut(),
      onError: (error) {
        AppErrorHandler.showSnackBar(context, error);
      },
      // AuthGateScreen listens to Firebase auth changes and will switch to
      // SignInScreen automatically after successful sign out.
      onSuccess: () {},
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openTranscription() {
    _navigateTo(
      ChangeNotifierProvider(
        create: (_) => TranscriptionController(),
        child: const TranscriptionScreen(),
      ),
    );
  }

  Widget _buildAppBarContent(String userName) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $userName',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              const Text(
                'Clinic command center',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PillIconButton(
              icon: Icons.person,
              onTap: () => _navigateTo(const DoctorProfileScreen()),
            ),
            const SizedBox(width: 8),
            _PillIconButton(
              icon: Icons.exit_to_app,
              onTap: _signOut,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroSpotlight() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_heroStart, _heroEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _heroGlow.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -45,
            left: -35,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.mic, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Consultation AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    _HeroChip(
                      icon: Icons.check_circle,
                      label: 'Ready',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Start a new consult',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Record once and generate summary + prescription instantly.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _HeroChip(icon: Icons.history, label: 'Last session: --'),
                    _HeroChip(icon: Icons.auto_awesome, label: 'Auto summary on'),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _HeroPrimaryButton(
                      label: 'Start Consultation',
                      icon: Icons.play_arrow_rounded,
                      onTap: _openTranscription,
                    ),
                    _HeroGhostButton(
                      label: 'Open Notes',
                      icon: Icons.note_alt,
                      onTap: () => _navigateTo(
                        ClinicalNotesScreen(patientId: 'new'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryShortcuts() {
    return Row(
      children: [
        Expanded(
          child: _PrimaryShortcutCard(
            title: 'Consultation AI',
            subtitle: 'Voice consult + auto summary',
            icon: Icons.mic_none,
            color: _brandBlue,
            onTap: _openTranscription,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PrimaryShortcutCard(
            title: 'Clinical Notes',
            subtitle: 'Document and organize notes',
            icon: Icons.note_alt,
            color: _brandTeal,
            onTap: () => _navigateTo(
              ClinicalNotesScreen(patientId: 'new'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsStrip() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: const [
          _InsightCard(title: 'Sessions this week', value: '0', caption: 'Target 3'),
          SizedBox(width: 12),
          _InsightCard(title: 'Avg time saved', value: '--', caption: 'Per consult'),
          SizedBox(width: 12),
          _InsightCard(title: 'Notes pending', value: '0', caption: 'Ready to review'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = _authService.currentUser?.displayName ?? 'Doctor';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final workflowCardAspectRatio = screenWidth <= 390 ? 1.05 : 1.12;

    return Scaffold(
      backgroundColor: _pageBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_pageBg, Color(0xFFEFF3F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: _pageBg,
                elevation: 0,
                toolbarHeight: 86,
                titleSpacing: 16,
                title: _buildAppBarContent(userName),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroSpotlight(),
                      const SizedBox(height: 16),
                      _buildPrimaryShortcuts(),
                      const SizedBox(height: 22),
                      _buildSectionHeader(
                        title: 'Workflows',
                        subtitle: 'Specialized tools for fast, structured notes.',
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        padding: EdgeInsets.zero,
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: workflowCardAspectRatio,
                        children: [
                          _WorkflowCard(
                            icon: Icons.local_pharmacy,
                            color: Colors.orange,
                            title: 'Medication Safety',
                            description: 'Check interactions and contraindications',
                            onTap: () => _navigateTo(MedicationSafetyScreen()),
                          ),
                          _WorkflowCard(
                            icon: Icons.assignment,
                            color: Colors.teal,
                            title: 'Shift Handoff',
                            description: 'Generate concise handoff summaries',
                            onTap: () => _navigateTo(ShiftHandoffScreen()),
                          ),
                          _WorkflowCard(
                            icon: Icons.emergency_share,
                            color: Colors.red,
                            title: 'Emergency Triage',
                            description: 'Prioritize urgent cases quickly',
                            onTap: () => _navigateTo(EmergencyTriageScreen()),
                          ),
                          _WorkflowCard(
                            icon: Icons.local_hospital,
                            color: Colors.indigo,
                            title: 'Ward Rounds',
                            description: 'Generate rounds summaries and plans',
                            onTap: () => _navigateTo(WardRoundsScreen()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _buildSectionHeader(
                        title: 'Quick Actions',
                        subtitle: 'Jump into your most used destinations.',
                      ),
                      const SizedBox(height: 12),
                      _ActionButton(
                        icon: Icons.group,
                        color: Colors.cyan,
                        title: 'My Patients',
                        description: 'View patient records and history',
                        onTap: () => _navigateTo(DoctorPatientsScreen()),
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        icon: Icons.note_alt,
                        color: Colors.deepPurple,
                        title: 'Recent Notes',
                        description: 'Continue editing recent documentation',
                        onTap: () => _navigateTo(
                          ClinicalNotesScreen(patientId: 'new'),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _buildSectionHeader(
                        title: 'Insights',
                        subtitle: 'Track your momentum through the week.',
                      ),
                      const SizedBox(height: 12),
                      _buildInsightsStrip(),
                      SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PillIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F3F7),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Icon(icon, color: const Color(0xFF1F2937), size: 18),
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HeroPrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF1D4ED8), size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroGhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HeroGhostButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryShortcutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String value;
  final String caption;

  const _InsightCard({
    required this.title,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _WorkflowCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: Colors.grey[400], size: 16),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
