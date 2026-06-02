import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import 'add_reminder_screen.dart';

/// Unified schedule: today's medication doses (tap to mark taken) plus upcoming
/// vaccinations, appointments and custom reminders with overdue flags.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  static String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final uid = context.read<HealthDataProvider>().uid;
    final db = FirestoreService();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Reminders & Schedule')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: uid == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddReminderScreen()),
                ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add reminder'),
      ),
      body: uid == null
          ? Center(child: Text('Sign in to manage reminders.',
              style: AppTheme.bodyMedium))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.lg, AppTheme.lg, AppTheme.lg, 96),
              children: [
                _AdherenceCard(uid: uid, db: db),
                _SectionTitle('Today · ${DateFormat('EEE, d MMM').format(DateTime.now())}'),
                const SizedBox(height: AppTheme.sm),
                _TodayDoses(uid: uid, db: db, dateKey: _todayKey()),
                const SizedBox(height: AppTheme.xl),
                _SectionTitle('Upcoming'),
                const SizedBox(height: AppTheme.sm),
                _UpcomingReminders(uid: uid, db: db),
              ],
            ),
    );
  }
}

// ── Today's medication doses ─────────────────────────────────────────────────

class _TodayDoses extends StatelessWidget {
  final String uid;
  final FirestoreService db;
  final String dateKey;
  const _TodayDoses(
      {required this.uid, required this.db, required this.dateKey});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Medication>>(
      stream: db.watchMedications(uid),
      builder: (context, medSnap) {
        final meds = (medSnap.data ?? [])
            .where((m) => m.isActive && m.reminderTimes.isNotEmpty)
            .toList();
        if (meds.isEmpty) {
          return _EmptyCard(
            icon: Icons.medication_outlined,
            text:
                'No medication reminders yet. Add reminder times to a medication to see today\'s doses here.',
          );
        }
        // Flatten into (med, time) dose slots sorted by time.
        final slots = <({Medication med, String time})>[];
        for (final m in meds) {
          for (final t in m.reminderTimes) {
            slots.add((med: m, time: t));
          }
        }
        slots.sort((a, b) => a.time.compareTo(b.time));

        return StreamBuilder<List<MedicationLog>>(
          stream: db.watchMedicationLogs(uid, dateKey),
          builder: (context, logSnap) {
            final logs = logSnap.data ?? [];
            return Column(
              children: [
                for (final s in slots)
                  _DoseTile(
                    uid: uid,
                    db: db,
                    dateKey: dateKey,
                    med: s.med,
                    time: s.time,
                    log: logs.firstWhere(
                      (l) =>
                          l.medicationId == s.med.id && l.time == s.time,
                      orElse: () => MedicationLog(),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DoseTile extends StatelessWidget {
  final String uid;
  final FirestoreService db;
  final String dateKey;
  final Medication med;
  final String time;
  final MedicationLog log;

  const _DoseTile({
    required this.uid,
    required this.db,
    required this.dateKey,
    required this.med,
    required this.time,
    required this.log,
  });

  String _logId() => '${med.id}|$dateKey|$time';

  Future<void> _set(String status) async {
    if (log.status == status && log.id.isNotEmpty) {
      await db.deleteMedicationLog(uid, _logId()); // toggle off
      return;
    }
    await db.saveMedicationLog(
      uid,
      MedicationLog(
        id: _logId(),
        medicationId: med.id,
        medicationName: med.name,
        date: dateKey,
        time: time,
        status: status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taken = log.id.isNotEmpty && log.status == 'taken';
    final skipped = log.id.isNotEmpty && log.status == 'skipped';
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.sm),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
            color: taken
                ? AppTheme.successColor.withValues(alpha: 0.4)
                : AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            alignment: Alignment.center,
            child: Text(_pretty(time),
                style: AppTheme.labelMedium
                    .copyWith(color: AppTheme.primaryColor)),
          ),
          const SizedBox(width: AppTheme.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name,
                    style: AppTheme.labelLarge.copyWith(
                      decoration: taken
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (med.dosage.isNotEmpty)
                  Text(med.dosage, style: AppTheme.labelSmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Skip',
            onPressed: () => _set('skipped'),
            icon: Icon(
              skipped ? Icons.cancel_rounded : Icons.cancel_outlined,
              color: skipped ? AppTheme.warningColor : AppTheme.textTertiary,
            ),
          ),
          IconButton(
            tooltip: 'Taken',
            onPressed: () => _set('taken'),
            icon: Icon(
              taken
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
              color: taken ? AppTheme.successColor : AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  String _pretty(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final dt = DateTime(2000, 1, 1, h, m);
    return DateFormat('h:mm a').format(dt);
  }
}

// ── Upcoming reminders ───────────────────────────────────────────────────────

class _UpcomingReminders extends StatelessWidget {
  final String uid;
  final FirestoreService db;
  const _UpcomingReminders({required this.uid, required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HealthReminder>>(
      stream: db.watchReminders(uid),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final pending = all.where((r) => !r.completed).toList();
        if (pending.isEmpty) {
          return _EmptyCard(
            icon: Icons.event_available_outlined,
            text:
                'No upcoming vaccinations, appointments or reminders. Tap “Add reminder”.',
          );
        }
        return Column(
          children: [
            for (final r in pending)
              _ReminderTile(uid: uid, db: db, reminder: r),
          ],
        );
      },
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final String uid;
  final FirestoreService db;
  final HealthReminder reminder;
  const _ReminderTile(
      {required this.uid, required this.db, required this.reminder});

  static const _meta = <String, (IconData, Color, String)>{
    'vaccination': (Icons.vaccines_outlined, AppTheme.infoColor, 'Vaccination'),
    'appointment': (
      Icons.event_outlined,
      AppTheme.primaryColor,
      'Appointment'
    ),
    'custom': (Icons.notifications_active_outlined, AppTheme.secondaryColor,
        'Reminder'),
  };

  Future<void> _complete() async {
    await db.saveReminder(
        uid, reminder.copyWith(completed: true, updatedAt: DateTime.now()));
    await NotificationService.instance
        .cancel(NotificationService.idFor(reminder.id));
  }

  Future<void> _delete() async {
    await db.deleteReminder(uid, reminder.id);
    await NotificationService.instance
        .cancel(NotificationService.idFor(reminder.id));
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta[reminder.type] ?? _meta['custom']!;
    final overdue = reminder.isOverdue;
    final dateStr = DateFormat('EEE, d MMM yyyy · h:mm a')
        .format(reminder.dateTime);

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.lg),
        margin: const EdgeInsets.only(bottom: AppTheme.sm),
        decoration: BoxDecoration(
          color: AppTheme.dangerColor.withValues(alpha: 0.12),
          borderRadius: AppTheme.mediumRadius,
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppTheme.dangerColor),
      ),
      onDismissed: (_) => _delete(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AddReminderScreen(existing: reminder)),
        ),
        child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.sm),
        padding: const EdgeInsets.all(AppTheme.md),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(
              color: overdue
                  ? AppTheme.dangerColor.withValues(alpha: 0.4)
                  : AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: meta.$2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(meta.$1, color: meta.$2, size: 20),
            ),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reminder.title.isEmpty ? meta.$3 : reminder.title,
                      style: AppTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                      reminder.isRecurring
                          ? '$dateStr · repeats ${reminder.recurrence}'
                          : dateStr,
                      style: AppTheme.labelSmall.copyWith(
                          color: overdue
                              ? AppTheme.dangerColor
                              : AppTheme.textTertiary)),
                  if (reminder.location.isNotEmpty)
                    Text(reminder.location,
                        style: AppTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Mark done',
              onPressed: _complete,
              icon: const Icon(Icons.check_circle_outline_rounded,
                  color: AppTheme.successColor),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ── Adherence stats (last 7 days) ────────────────────────────────────────────

class _AdherenceCard extends StatelessWidget {
  final String uid;
  final FirestoreService db;
  const _AdherenceCard({required this.uid, required this.db});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List<DateTime>.generate(
        7, (i) => DateTime(today.year, today.month, today.day - (6 - i)));
    final sinceKey = DateFormat('yyyy-MM-dd').format(days.first);

    return StreamBuilder<List<Medication>>(
      stream: db.watchMedications(uid),
      builder: (context, medSnap) {
        final slotsPerDay = (medSnap.data ?? [])
            .where((m) => m.isActive)
            .fold<int>(0, (sum, m) => sum + m.reminderTimes.length);
        if (slotsPerDay == 0) return const SizedBox.shrink();

        return StreamBuilder<List<MedicationLog>>(
          stream: db.watchRecentMedicationLogs(uid, sinceKey),
          builder: (context, logSnap) {
            final logs = logSnap.data ?? [];
            final takenByDay = <String, int>{};
            var takenTotal = 0;
            for (final l in logs) {
              if (l.status != 'taken') continue;
              takenTotal++;
              takenByDay[l.date] = (takenByDay[l.date] ?? 0) + 1;
            }
            final expected = slotsPerDay * 7;
            final pct = expected == 0
                ? 0
                : ((takenTotal / expected) * 100).round().clamp(0, 100);

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.lg),
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                gradient: AppTheme.successGradient,
                borderRadius: AppTheme.largeRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This week’s adherence',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('$pct%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800)),
                  Text('$takenTotal of $expected scheduled doses taken',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: AppTheme.md),
                  Row(
                    children: days.map((d) {
                      final key = DateFormat('yyyy-MM-dd').format(d);
                      final taken = takenByDay[key] ?? 0;
                      final frac =
                          slotsPerDay == 0 ? 0.0 : (taken / slotsPerDay).clamp(0.0, 1.0);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 40,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor:
                                        frac == 0 ? 0.06 : frac,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                            alpha: frac == 0 ? 0.25 : 0.9),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(DateFormat('E').format(d)[0],
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── small helpers ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTheme.headingSmall);
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyCard({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textTertiary, size: 22),
          const SizedBox(width: AppTheme.md),
          Expanded(child: Text(text, style: AppTheme.bodySmall)),
        ],
      ),
    );
  }
}
