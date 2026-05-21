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
import 'lab_values_screen.dart';
import 'document_scanner_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  static const Color _pageBg = Color(0xFFF6F7FB);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _brandBlue = Color(0xFF2563EB);

  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  int _patientCount = 0;
  int _sessionsThisWeek = 0;
  String _lastSessionText = '--';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final doctorId = _authService.currentUser?.uid;
    if (doctorId == null || doctorId.isEmpty) return;

    try {
      final patients = await _firestoreService.getDoctorPatients(doctorId);
      final sessions = await _firestoreService.getConsultationHistory(doctorId: doctorId);

      final weekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
      final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final thisWeek = sessions.where((s) => s.createdAt.isAfter(weekStartDay)).toList();

      String lastText = '--';
      if (sessions.isNotEmpty) {
        final last = sessions.first.createdAt;
        final diff = DateTime.now().difference(last);
        if (diff.inMinutes < 60) lastText = '${diff.inMinutes}m ago';
        else if (diff.inHours < 24) lastText = '${diff.inHours}h ago';
        else lastText = '${diff.inDays}d ago';
      }

      if (mounted) {
        setState(() {
          _patientCount = patients.length;
          _sessionsThisWeek = thisWeek.length;
          _lastSessionText = lastText;
        });
      }
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
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.4,
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
        color: _brandBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Start consultation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Record once. Get summary + prescription.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroPrimaryButton(
                  label: 'Record',
                  icon: Icons.mic_rounded,
                  onTap: _openTranscription,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroGhostButton(
                  label: 'Notes',
                  icon: Icons.note_alt_outlined,
                  onTap: () => _navigateTo(
                    ClinicalNotesScreen(patientId: 'new'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsStrip() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _InsightCard(
            title: 'Sessions this week',
            value: '$_sessionsThisWeek',
            caption: _sessionsThisWeek >= 3 ? 'Target met ✓' : 'Target 3',
          ),
          const SizedBox(width: 12),
          _InsightCard(
            title: 'Total patients',
            value: '$_patientCount',
            caption: 'In your care',
          ),
          const SizedBox(width: 12),
          _InsightCard(
            title: 'Last session',
            value: _lastSessionText,
            caption: 'Most recent',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = _authService.currentUser?.displayName ?? 'Doctor';

    return Scaffold(
      backgroundColor: _pageBg,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: _pageBg,
              elevation: 0,
              toolbarHeight: 80,
              titleSpacing: 16,
              title: _buildAppBarContent(userName),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeroSpotlight(),
                  const SizedBox(height: 28),

                  _buildSectionHeader(title: 'Workflows'),
                  GridView.count(
                    padding: EdgeInsets.zero,
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                    children: [
                      _WorkflowCard(
                        icon: Icons.local_pharmacy_outlined,
                        color: const Color(0xFFEA580C),
                        title: 'Meds',
                        onTap: () => _navigateTo(MedicationSafetyScreen()),
                      ),
                      _WorkflowCard(
                        icon: Icons.assignment_outlined,
                        color: const Color(0xFF14B8A6),
                        title: 'Handoff',
                        onTap: () => _navigateTo(ShiftHandoffScreen()),
                      ),
                      _WorkflowCard(
                        icon: Icons.emergency_share_outlined,
                        color: const Color(0xFFDC2626),
                        title: 'Triage',
                        onTap: () => _navigateTo(EmergencyTriageScreen()),
                      ),
                      _WorkflowCard(
                        icon: Icons.local_hospital_outlined,
                        color: const Color(0xFF4F46E5),
                        title: 'Rounds',
                        onTap: () => _navigateTo(WardRoundsScreen()),
                      ),
                      _WorkflowCard(
                        icon: Icons.biotech_outlined,
                        color: const Color(0xFF0891B2),
                        title: 'Labs',
                        onTap: () => _navigateTo(const LabValuesScreen()),
                      ),
                      _WorkflowCard(
                        icon: Icons.document_scanner_outlined,
                        color: const Color(0xFF9333EA),
                        title: 'Scan',
                        onTap: () => _navigateTo(
                            const DocumentScannerScreen(patientId: 'new')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  _buildSectionHeader(title: 'Quick Access'),
                  _ActionButton(
                    icon: Icons.group_outlined,
                    color: const Color(0xFF06B6D4),
                    title: 'My Patients',
                    trailing: _patientCount > 0 ? '$_patientCount' : null,
                    onTap: () => _navigateTo(DoctorPatientsScreen()),
                  ),
                  const SizedBox(height: 8),
                  _ActionButton(
                    icon: Icons.note_alt_outlined,
                    color: const Color(0xFF7C3AED),
                    title: 'Recent Notes',
                    onTap: () => _navigateTo(
                      ClinicalNotesScreen(patientId: 'new'),
                    ),
                  ),
                  const SizedBox(height: 28),

                  _buildSectionHeader(title: 'This week'),
                  _buildInsightsStrip(),
                ]),
              ),
            ),
          ],
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

/// Tiny iOS-style grid tile: tinted icon over title. Hairline border, no shadow.
class _WorkflowCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const _WorkflowCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS-style list row: tinted icon + title + optional trailing label + chevron.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) ...[
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.chevron_right,
                  color: Color(0xFFC7CACE), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
