import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';

/// "Care" tab — the everyday health utilities (medications, reminders,
/// symptom journal, health details) in one hub. Retention surface; the
/// money features live on Home / Cases.
class CareHubScreen extends StatefulWidget {
  const CareHubScreen({super.key});

  @override
  State<CareHubScreen> createState() => _CareHubScreenState();
}

class _CareHubScreenState extends State<CareHubScreen> {
  final _db = FirestoreService();
  String? _uid;
  String? _dateKey;
  Stream<List<Medication>>? _meds;
  Stream<List<MedicationLog>>? _logs;
  Stream<List<HealthReminder>>? _reminders;

  void _ensure(String? uid) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (uid == null || (uid == _uid && today == _dateKey)) return;
    _uid = uid;
    _dateKey = today;
    _meds = _db.watchMedications(uid);
    _logs = _db.watchMedicationLogs(uid, today);
    _reminders = _db.watchReminders(uid);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthDataProvider>();
    final uid = provider.uid;
    _ensure(uid);
    final profile = provider.profile;

    return LargeTitleScaffold(
      title: 'Care',
      subtitle: 'Medications, appointments, symptoms and your health details',
      automaticallyImplyLeading: false,
      contentPadding: const EdgeInsets.fromLTRB(DS.gutter, 4, DS.gutter, 120),
      children: [
        if (uid != null) _TodaySection(uid: uid, db: _db, dateKey: _dateKey!, meds: _meds, logs: _logs),
        if (uid != null) _UpcomingSection(reminders: _reminders),
        const DSSectionLabel('TOOLS'),
        InsetCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              InsetRow(
                icon: CupertinoIcons.capsule_fill,
                iconColor: AppTheme.successColor,
                title: 'Medications',
                subtitle: 'Active & past medicines, dose reminders',
                onTap: () => Navigator.pushNamed(context, AppRouter.medications),
              ),
              InsetRow(
                icon: CupertinoIcons.calendar,
                iconColor: AppTheme.secondaryColor,
                title: 'Reminders & appointments',
                subtitle: 'Vaccinations, visits, follow-ups',
                onTap: () => Navigator.pushNamed(context, AppRouter.reminders),
              ),
              InsetRow(
                icon: CupertinoIcons.waveform_path_ecg,
                iconColor: AppTheme.dangerColor,
                title: 'Symptom journal',
                subtitle: 'Log how you feel; spot trends',
                onTap: () => Navigator.pushNamed(context, AppRouter.symptomJournal),
              ),
              InsetRow(
                icon: CupertinoIcons.person_crop_circle_fill,
                iconColor: AppTheme.primaryColor,
                title: 'Health details',
                subtitle: _healthSummary(profile),
                onTap: () => Navigator.pushNamed(context, AppRouter.healthProfile),
              ),
              InsetRow(
                icon: CupertinoIcons.chat_bubble_2_fill,
                iconColor: AppTheme.infoColor,
                title: 'Ask a general health question',
                subtitle: 'Information only — not medical advice',
                onTap: () => Navigator.pushNamed(context, AppRouter.aiChat, arguments: 'health'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Clinix provides general information and organisation tools. It does not diagnose or treat. In an emergency, call your local emergency number.',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary, height: 1.4),
        ),
      ],
    );
  }

  static String _healthSummary(PatientProfile? p) {
    if (p == null) return 'Allergies, conditions, emergency contact';
    final parts = <String>[];
    if (p.allAllergies.isNotEmpty) parts.add('${p.allAllergies.length} allergies');
    final cond = p.chronicConditions.length + p.pastDiseases.length;
    if (cond > 0) parts.add('$cond conditions');
    if (p.bloodGroup.isNotEmpty && p.bloodGroup != 'Unknown') parts.add(p.bloodGroup);
    return parts.isEmpty ? 'Add allergies, conditions, emergency contact' : parts.join(' · ');
  }
}

// ── Today's doses ─────────────────────────────────────────────────────────────

class _TodaySection extends StatelessWidget {
  final String uid;
  final FirestoreService db;
  final String dateKey;
  final Stream<List<Medication>>? meds;
  final Stream<List<MedicationLog>>? logs;
  const _TodaySection({required this.uid, required this.db, required this.dateKey, required this.meds, required this.logs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Medication>>(
      stream: meds,
      builder: (context, medSnap) {
        final active = (medSnap.data ?? const <Medication>[])
            .where((m) => m.isActive && m.reminderTimes.isNotEmpty)
            .toList();
        final slots = <({Medication med, String time})>[
          for (final m in active)
            for (final t in m.reminderTimes) (med: m, time: t),
        ]..sort((a, b) => a.time.compareTo(b.time));

        return StreamBuilder<List<MedicationLog>>(
          stream: logs,
          builder: (context, logSnap) {
            final logList = logSnap.data ?? const <MedicationLog>[];
            final taken = slots.where((s) => logList.any((l) => l.medicationId == s.med.id && l.time == s.time && l.status == 'taken')).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DSSectionLabel(
                  'TODAY',
                  trailing: slots.isEmpty
                      ? null
                      : Text('$taken of ${slots.length} taken',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                ),
                if (slots.isEmpty)
                  InsetCard(
                    child: Row(
                      children: [
                        IconBadge(CupertinoIcons.capsule, color: AppTheme.successColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No dose reminders today. Add reminder times to a medication and they will show up here.',
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  InsetCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final s in slots)
                          _DoseRow(
                            med: s.med,
                            time: s.time,
                            log: logList.firstWhere(
                              (l) => l.medicationId == s.med.id && l.time == s.time,
                              orElse: () => MedicationLog(),
                            ),
                            onSet: (status) => _set(s.med, s.time, status, logList),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _set(Medication med, String time, String status, List<MedicationLog> logs) async {
    final id = '${med.id}|$dateKey|$time';
    final existing = logs.where((l) => l.id == id).firstOrNull;
    if (existing != null && existing.status == status) {
      await db.deleteMedicationLog(uid, id);
      return;
    }
    await db.saveMedicationLog(
      uid,
      MedicationLog(id: id, medicationId: med.id, medicationName: med.name, date: dateKey, time: time, status: status),
    );
  }
}

class _DoseRow extends StatelessWidget {
  final Medication med;
  final String time;
  final MedicationLog log;
  final ValueChanged<String> onSet;
  const _DoseRow({required this.med, required this.time, required this.log, required this.onSet});

  @override
  Widget build(BuildContext context) {
    final taken = log.id.isNotEmpty && log.status == 'taken';
    final skipped = log.id.isNotEmpty && log.status == 'skipped';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(_pretty(time),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        decoration: skipped ? TextDecoration.lineThrough : null)),
                if (med.dosage.isNotEmpty)
                  Text(med.dosage, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          _DoseButton(
            icon: CupertinoIcons.checkmark_alt,
            color: AppTheme.successColor,
            active: taken,
            onTap: () => onSet('taken'),
          ),
          const SizedBox(width: 6),
          _DoseButton(
            icon: CupertinoIcons.xmark,
            color: AppTheme.textTertiary,
            active: skipped,
            onTap: () => onSet('skipped'),
          ),
        ],
      ),
    );
  }

  static String _pretty(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $suffix';
  }
}

class _DoseButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _DoseButton({required this.icon, required this.color, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DSPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: active ? Colors.white : color),
      ),
    );
  }
}

// ── Upcoming reminders ────────────────────────────────────────────────────────

class _UpcomingSection extends StatelessWidget {
  final Stream<List<HealthReminder>>? reminders;
  const _UpcomingSection({required this.reminders});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HealthReminder>>(
      stream: reminders,
      builder: (context, snap) {
        final now = DateTime.now();
        final upcoming = (snap.data ?? const <HealthReminder>[])
            .where((r) => !r.completed && r.dateTime.isAfter(now.subtract(const Duration(hours: 12))))
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
        if (upcoming.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DSSectionLabel('UPCOMING'),
            InsetCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final r in upcoming.take(3))
                    InsetRow(
                      icon: r.type == 'appointment'
                          ? CupertinoIcons.calendar
                          : r.type == 'vaccination'
                              ? CupertinoIcons.bandage_fill
                              : CupertinoIcons.bell_fill,
                      iconColor: AppTheme.secondaryColor,
                      title: r.title,
                      subtitle: DateFormat('EEE d MMM · h:mm a').format(r.dateTime) +
                          (r.location.isNotEmpty ? ' · ${r.location}' : ''),
                      onTap: () => Navigator.pushNamed(context, AppRouter.reminders),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
        );
      },
    );
  }
}
