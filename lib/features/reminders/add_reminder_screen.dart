import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

/// Creates (or edits) a vaccination / appointment / custom reminder and
/// schedules a local notification for it.
class AddReminderScreen extends StatefulWidget {
  final HealthReminder? existing;
  const AddReminderScreen({super.key, this.existing});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _db = FirestoreService();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _type = 'appointment';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _notifyBefore = 60;
  String _recurrence = 'none';
  bool _saving = false;

  static const _recurrenceOptions = <String, String>{
    'none': 'Does not repeat',
    'daily': 'Every day',
    'weekly': 'Every week',
    'monthly': 'Every month',
  };

  static const _types = <String, (IconData, String)>{
    'vaccination': (Icons.vaccines_outlined, 'Vaccination'),
    'appointment': (Icons.event_outlined, 'Appointment'),
    'custom': (Icons.notifications_active_outlined, 'Reminder'),
  };

  static const _notifyOptions = <int, String>{
    0: 'At time',
    30: '30 min before',
    60: '1 hour before',
    180: '3 hours before',
    1440: '1 day before',
    2880: '2 days before',
    10080: '1 week before',
  };

  @override
  void initState() {
    super.initState();
    // Ask for notification permission up front so scheduling can succeed.
    NotificationService.instance.requestPermissions();
    final e = widget.existing;
    if (e != null) {
      _type = _types.containsKey(e.type) ? e.type : 'custom';
      _titleCtrl.text = e.title;
      _locationCtrl.text = e.location;
      _notesCtrl.text = e.notes;
      _date = e.dateTime;
      _time = TimeOfDay(hour: e.dateTime.hour, minute: e.dateTime.minute);
      _notifyBefore =
          _notifyOptions.containsKey(e.notifyMinutesBefore)
              ? e.notifyMinutesBefore
              : 60;
      _recurrence =
          _recurrenceOptions.containsKey(e.recurrence) ? e.recurrence : 'none';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  DateTime get _dateTime =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give the reminder a title.')));
      return;
    }
    final uid = context.read<HealthDataProvider>().uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final id = widget.existing?.id.isNotEmpty == true
          ? widget.existing!.id
          : const Uuid().v4();
      final reminder = HealthReminder(
        id: id,
        userId: uid,
        type: _type,
        title: _titleCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        dateTime: _dateTime,
        location: _locationCtrl.text.trim(),
        notifyMinutesBefore: _notifyBefore,
        recurrence: _recurrence,
        completed: false,
        createdAt: widget.existing?.createdAt,
      );
      await _db.saveReminder(uid, reminder);

      // (Re)schedule the local notification.
      final notifId = NotificationService.idFor(id);
      await NotificationService.instance.cancel(notifId);
      await NotificationService.instance.scheduleRecurring(
        id: notifId,
        title: _typeLabel,
        body: reminder.location.isEmpty
            ? reminder.title
            : '${reminder.title} · ${reminder.location}',
        first: reminder.notifyAt,
        recurrence: _recurrence,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _typeLabel => _types[_type]?.$2 ?? 'Reminder';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Reminder' : 'Edit Reminder'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.lg),
        children: [
          _Card(children: [
            Text('Type', style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.md),
            Row(
              children: _types.entries.map((e) {
                final sel = _type == e.key;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _type = e.key),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : AppTheme.surfaceMuted,
                        borderRadius: AppTheme.mediumRadius,
                        border: Border.all(
                            color: sel
                                ? AppTheme.primaryColor
                                : Colors.transparent),
                      ),
                      child: Column(
                        children: [
                          Icon(e.value.$1,
                              size: 22,
                              color: sel
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary),
                          const SizedBox(height: 4),
                          Text(e.value.$2,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: sel
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ]),
          const SizedBox(height: AppTheme.lg),
          _Card(children: [
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: _type == 'vaccination'
                    ? 'e.g. Hepatitis B – 2nd dose'
                    : _type == 'appointment'
                        ? 'e.g. Dr. Lee – cardiology review'
                        : 'e.g. Refill prescription',
              ),
            ),
            if (_type == 'appointment') ...[
              const SizedBox(height: AppTheme.md),
              TextField(
                controller: _locationCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Clinic / Provider (optional)',
                  hintText: 'Where is it?',
                ),
              ),
            ],
            const SizedBox(height: AppTheme.md),
            Row(
              children: [
                Expanded(
                  child: _PickField(
                    label: 'Date',
                    value: DateFormat('EEE, d MMM yyyy').format(_date),
                    icon: Icons.calendar_today_rounded,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickField(
                    label: 'Time',
                    value: _time.format(context),
                    icon: Icons.access_time_rounded,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.md),
            DropdownButtonFormField<int>(
              initialValue: _notifyBefore,
              decoration: const InputDecoration(labelText: 'Remind me'),
              items: _notifyOptions.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _notifyBefore = v ?? 60),
            ),
            const SizedBox(height: AppTheme.md),
            DropdownButtonFormField<String>(
              initialValue: _recurrence,
              decoration: const InputDecoration(labelText: 'Repeat'),
              items: _recurrenceOptions.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _recurrence = v ?? 'none'),
            ),
            const SizedBox(height: AppTheme.md),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
            ),
          ]),
          const SizedBox(height: AppTheme.xl),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
              shape:
                  RoundedRectangleBorder(borderRadius: AppTheme.mediumRadius),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save Reminder',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          const SizedBox(height: AppTheme.xxl),
        ],
      ),
    );
  }
}

class _PickField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const _PickField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: Icon(icon, size: 16),
          ),
          controller: TextEditingController(text: value),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppTheme.lg),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children),
      );
}
