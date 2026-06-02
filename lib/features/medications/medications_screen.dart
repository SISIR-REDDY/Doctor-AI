import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _db = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<HealthDataProvider>().uid;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Medications'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Past'),
          ],
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : StreamBuilder<List<Medication>>(
              stream: _db.watchMedications(uid),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data ?? [];
                final active = all.where((m) => m.isActive).toList();
                final past = all.where((m) => !m.isActive).toList();

                return TabBarView(
                  controller: _tabs,
                  children: [
                    _MedList(
                      meds: active,
                      emptyLabel: 'No active medications',
                      emptyIcon: Icons.medication_outlined,
                      onDelete: (m) => _delete(uid, m),
                      onToggle: (m) => _toggle(uid, m),
                      onEdit: (m) => _showAddSheet(context, uid, existing: m),
                    ),
                    _MedList(
                      meds: past,
                      emptyLabel: 'No past medications',
                      emptyIcon: Icons.history_rounded,
                      onDelete: (m) => _delete(uid, m),
                      onToggle: (m) => _toggle(uid, m),
                      onEdit: (m) => _showAddSheet(context, uid, existing: m),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, uid ?? ''),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Medication'),
        backgroundColor: AppTheme.surgeryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _delete(String uid, Medication med) async {
    await _db.deleteMedication(uid, med.id);
    // Cancel any daily reminders scheduled for this medication.
    for (final t in med.reminderTimes) {
      await NotificationService.instance
          .cancel(NotificationService.idFor('${med.id}|$t'));
    }
  }

  Future<void> _toggle(String uid, Medication med) async {
    final updated = med.copyWith(isActive: !med.isActive);
    await _db.saveMedication(uid, updated);
    // Pause reminders when inactive; resume when active again.
    for (final t in med.reminderTimes) {
      final id = NotificationService.idFor('${med.id}|$t');
      if (updated.isActive) {
        final p = t.split(':');
        await NotificationService.instance.scheduleDaily(
          id: id,
          title: 'Medication reminder',
          body: med.dosage.isEmpty
              ? 'Time to take ${med.name}'
              : 'Time to take ${med.name} (${med.dosage})',
          hour: int.tryParse(p[0]) ?? 8,
          minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
        );
      } else {
        await NotificationService.instance.cancel(id);
      }
    }
  }

  void _showAddSheet(BuildContext context, String uid, {Medication? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMedSheet(uid: uid, db: _db, existing: existing),
    );
  }
}

// ── Med List ──────────────────────────────────────────────────────────────────

class _MedList extends StatelessWidget {
  final List<Medication> meds;
  final String emptyLabel;
  final IconData emptyIcon;
  final ValueChanged<Medication> onDelete;
  final ValueChanged<Medication> onToggle;
  final ValueChanged<Medication> onEdit;

  const _MedList({
    required this.meds,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.onDelete,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (meds.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 56, color: AppTheme.textTertiary),
            const SizedBox(height: AppTheme.lg),
            Text(emptyLabel, style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.sm),
            Text('Tap + to add a medication',
                style: AppTheme.bodySmall),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.lg),
      itemCount: meds.length,
      itemBuilder: (_, i) => _MedCard(
        med: meds[i],
        onDelete: () => onDelete(meds[i]),
        onToggle: () => onToggle(meds[i]),
        onEdit: () => onEdit(meds[i]),
      ),
    );
  }
}

// ── Med Card ──────────────────────────────────────────────────────────────────

class _MedCard extends StatelessWidget {
  final Medication med;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  const _MedCard(
      {required this.med,
      required this.onDelete,
      required this.onToggle,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surgeryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medication_rounded,
                    color: AppTheme.surgeryColor, size: 22),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name,
                        style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('${med.dosage} · ${med.frequency}',
                        style: AppTheme.bodySmall),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: AppTheme.textTertiary),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'toggle') onToggle();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(med.isActive
                        ? 'Mark as Inactive'
                        : 'Mark as Active'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: AppTheme.dangerColor)),
                  ),
                ],
              ),
            ],
          ),
          if (med.purpose.isNotEmpty) ...[
            const SizedBox(height: AppTheme.sm),
            Text('Purpose: ${med.purpose}',
                style: AppTheme.bodySmall),
          ],
          if (med.prescribingDoctor.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Prescribed by: ${med.prescribingDoctor}',
                style: AppTheme.bodySmall),
          ],
          const SizedBox(height: AppTheme.sm),
          Row(
            children: [
              if (med.startDate.isNotEmpty) ...[
                Icon(Icons.calendar_today_rounded,
                    size: 12, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text('Started: ${med.startDate}',
                    style: AppTheme.bodySmall.copyWith(fontSize: 11)),
              ],
              if (med.endDate.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(Icons.event_available_rounded,
                    size: 12, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text('Until: ${med.endDate}',
                    style: AppTheme.bodySmall.copyWith(fontSize: 11)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add Med Sheet ─────────────────────────────────────────────────────────────

class _AddMedSheet extends StatefulWidget {
  final String uid;
  final FirestoreService db;
  final Medication? existing;
  const _AddMedSheet({required this.uid, required this.db, this.existing});

  @override
  State<_AddMedSheet> createState() => _AddMedSheetState();
}

class _AddMedSheetState extends State<_AddMedSheet> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _frequency = 'Once daily';
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _reminderTimes = [];
  bool _saving = false;

  final _frequencies = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'Every 8 hours',
    'Every 12 hours',
    'As needed',
    'Weekly',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _dosageCtrl.text = e.dosage;
      _purposeCtrl.text = e.purpose;
      _doctorCtrl.text = e.prescribingDoctor;
      _notesCtrl.text = e.notes;
      _frequency = _frequencies.contains(e.frequency) ? e.frequency : 'Other';
      _reminderTimes.addAll(e.reminderTimes);
      if (e.startDate.isNotEmpty) {
        try {
          _startDate = DateFormat('dd MMM yyyy').parse(e.startDate);
        } catch (_) {}
      }
      if (e.endDate.isNotEmpty) {
        try {
          _endDate = DateFormat('dd MMM yyyy').parse(e.endDate);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _purposeCtrl.dispose();
    _doctorCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d != null) {
      setState(() {
        if (isStart) {
          _startDate = d;
        } else {
          _endDate = d;
        }
      });
    }
  }

  Future<void> _addReminderTime() async {
    final t = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
    if (t == null) return;
    final hhmm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (!_reminderTimes.contains(hhmm)) {
      setState(() {
        _reminderTimes.add(hhmm);
        _reminderTimes.sort();
      });
    }
  }

  String _prettyTime(String hhmm) {
    final p = hhmm.split(':');
    if (p.length != 2) return hhmm;
    return TimeOfDay(hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0)
        .format(context);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      final med = Medication(
        id: existing?.id ?? const Uuid().v4(),
        userId: widget.uid,
        name: _nameCtrl.text.trim(),
        dosage: _dosageCtrl.text.trim(),
        frequency: _frequency,
        purpose: _purposeCtrl.text.trim(),
        prescribingDoctor: _doctorCtrl.text.trim(),
        startDate: _startDate != null
            ? DateFormat('dd MMM yyyy').format(_startDate!)
            : '',
        endDate: _endDate != null
            ? DateFormat('dd MMM yyyy').format(_endDate!)
            : '',
        notes: _notesCtrl.text.trim(),
        reminderTimes: List<String>.from(_reminderTimes),
        isActive: existing?.isActive ?? true,
        createdAt: existing?.createdAt,
      );

      // Cancel any previously-scheduled reminders for this med (times may
      // have changed since the last save).
      for (final t in existing?.reminderTimes ?? const <String>[]) {
        await NotificationService.instance
            .cancel(NotificationService.idFor('${med.id}|$t'));
      }

      await widget.db.saveMedication(widget.uid, med);

      // Schedule a daily notification at each reminder time.
      if (_reminderTimes.isNotEmpty && med.isActive) {
        await NotificationService.instance.requestPermissions();
        for (final t in _reminderTimes) {
          final p = t.split(':');
          await NotificationService.instance.scheduleDaily(
            id: NotificationService.idFor('${med.id}|$t'),
            title: 'Medication reminder',
            body: med.dosage.isEmpty
                ? 'Time to take ${med.name}'
                : 'Time to take ${med.name} (${med.dosage})',
            hour: int.tryParse(p[0]) ?? 8,
            minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(AppTheme.xl),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.lg),
              Text(widget.existing == null ? 'Add Medication' : 'Edit Medication',
                  style: AppTheme.headingSmall),
              const SizedBox(height: AppTheme.lg),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Medication Name *',
                  hintText: 'e.g. Paracetamol 500mg',
                ),
              ),
              const SizedBox(height: AppTheme.md),
              TextField(
                controller: _dosageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dosage',
                  hintText: 'e.g. 500mg, 1 tablet',
                ),
              ),
              const SizedBox(height: AppTheme.md),
              DropdownButtonFormField<String>(
                value: _frequency,
                decoration:
                    const InputDecoration(labelText: 'Frequency'),
                items: _frequencies
                    .map((f) =>
                        DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => _frequency = v!),
              ),
              const SizedBox(height: AppTheme.md),
              TextField(
                controller: _purposeCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  hintText: 'e.g. For fever and pain relief',
                ),
              ),
              const SizedBox(height: AppTheme.md),
              TextField(
                controller: _doctorCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Prescribed by',
                  hintText: 'Doctor\'s name',
                ),
              ),
              const SizedBox(height: AppTheme.md),
              Row(
                children: [
                  Expanded(
                    child: _DatePicker(
                      label: 'Start Date',
                      date: _startDate,
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DatePicker(
                      label: 'End Date',
                      date: _endDate,
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.md),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Any special instructions...',
                ),
              ),
              const SizedBox(height: AppTheme.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Reminder times',
                    style: AppTheme.labelLarge),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Get a daily notification to take this medication',
                    style: AppTheme.labelSmall),
              ),
              const SizedBox(height: AppTheme.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _reminderTimes)
                    InputChip(
                      label: Text(_prettyTime(t)),
                      avatar: const Icon(Icons.alarm_rounded, size: 16),
                      onDeleted: () =>
                          setState(() => _reminderTimes.remove(t)),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded,
                        size: 16, color: AppTheme.primaryColor),
                    label: const Text('Add time',
                        style: TextStyle(color: AppTheme.primaryColor)),
                    onPressed: _addReminderTime,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.xl),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surgeryColor,
                  padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.md),
                  shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.mediumRadius),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Medication',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
              ),
              const SizedBox(height: AppTheme.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DatePicker(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Select date',
            suffixIcon:
                const Icon(Icons.calendar_today_rounded, size: 16),
          ),
          controller: TextEditingController(
              text: date != null
                  ? DateFormat('dd MMM yyyy').format(date!)
                  : ''),
        ),
      ),
    );
  }
}
