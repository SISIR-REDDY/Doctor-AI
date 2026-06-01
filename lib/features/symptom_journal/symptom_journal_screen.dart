import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/chatbot_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';

class SymptomJournalScreen extends StatefulWidget {
  const SymptomJournalScreen({super.key});

  @override
  State<SymptomJournalScreen> createState() => _SymptomJournalScreenState();
}

class _SymptomJournalScreenState extends State<SymptomJournalScreen> {
  final _db = FirestoreService();
  String? _aiTrend;
  bool _loadingTrend = false;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<HealthDataProvider>().uid;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Symptom Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'AI Trend Analysis',
            onPressed: uid != null ? () => _analyzeTrend(uid) : null,
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in to view your journal'))
          : Column(
              children: [
                if (_aiTrend != null) _TrendCard(text: _aiTrend!),
                if (_loadingTrend)
                  LinearProgressIndicator(
                    backgroundColor: AppTheme.dividerColor,
                    color: AppTheme.primaryColor,
                  ),
                Expanded(
                  child: StreamBuilder<List<SymptomEntry>>(
                    stream: _db.watchSymptoms(uid),
                    builder: (ctx, snap) {
                      if (snap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final entries = snap.data ?? [];
                      if (entries.isEmpty) {
                        return _EmptyState();
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.lg),
                        itemCount: entries.length,
                        itemBuilder: (_, i) => _SymptomCard(
                          entry: entries[i],
                          onDelete: () =>
                              _delete(uid, entries[i].id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, uid ?? ''),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log Symptom'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _analyzeTrend(String uid) async {
    setState(() {
      _loadingTrend = true;
      _aiTrend = null;
    });
    try {
      final entries = await _db.watchSymptoms(uid).first;
      if (entries.isEmpty) {
        setState(() {
          _aiTrend = 'No symptoms logged yet. Start tracking to get AI analysis.';
          _loadingTrend = false;
        });
        return;
      }
      final recent = entries.take(20).toList();
      final summary = recent
          .map((e) =>
              '${DateFormat('dd MMM').format(e.loggedAt)}: ${e.symptom} (severity ${e.severity}/10, ${e.bodyLocation})')
          .join('\n');

      final prompt =
          '''Analyze these recent health symptoms and give a brief trend analysis in 3-4 sentences. Mention any patterns, recurring issues, or concerning trends. Recommend if a doctor visit is needed.

Symptoms:
$summary''';

      final response = await ChatbotService().getGeminiResponse(prompt);
      if (mounted) {
        setState(() {
          _aiTrend = response;
          _loadingTrend = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingTrend = false);
        final msg = e.toString().replaceFirst('Exception: ', '').trim();
        setState(() => _aiTrend = msg.isEmpty ? 'Unable to analyze trends.' : msg);
      }
    }
  }

  Future<void> _delete(String uid, String id) async {
    await _db.deleteSymptom(uid, id);
  }

  void _showAddSheet(BuildContext context, String uid) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSymptomSheet(uid: uid, db: _db),
    );
  }
}

// ── Trend Card ────────────────────────────────────────────────────────────────

class _TrendCard extends StatelessWidget {
  final String text;
  const _TrendCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.lg),
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Trend Analysis',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(text,
                    style: AppTheme.bodySmall.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Symptom Card ──────────────────────────────────────────────────────────────

class _SymptomCard extends StatelessWidget {
  final SymptomEntry entry;
  final VoidCallback onDelete;
  const _SymptomCard({required this.entry, required this.onDelete});

  Color get _severityColor {
    if (entry.severity <= 3) return AppTheme.successColor;
    if (entry.severity <= 6) return AppTheme.warningColor;
    return AppTheme.dangerColor;
  }

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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _severityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${entry.severity}',
                style: TextStyle(
                  color: _severityColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.symptom,
                    style: AppTheme.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                if (entry.bodyLocation.isNotEmpty)
                  Text(entry.bodyLocation,
                      style: AppTheme.bodySmall),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                        '${DateFormat('dd MMM, hh:mm a').format(entry.loggedAt)} · ${entry.timeOfDay}',
                        style: AppTheme.bodySmall
                            .copyWith(fontSize: 11)),
                  ],
                ),
                if (entry.notes.isNotEmpty)
                  Text(entry.notes,
                      style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppTheme.textTertiary, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note_rounded,
              size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: AppTheme.lg),
          const Text('No symptoms logged yet',
              style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.sm),
          const Text('Track your daily symptoms to get AI trend analysis',
              style: AppTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Add Symptom Sheet ─────────────────────────────────────────────────────────

class _AddSymptomSheet extends StatefulWidget {
  final String uid;
  final FirestoreService db;
  const _AddSymptomSheet({required this.uid, required this.db});

  @override
  State<_AddSymptomSheet> createState() => _AddSymptomSheetState();
}

class _AddSymptomSheetState extends State<_AddSymptomSheet> {
  final _symptomCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int _severity = 5;
  String _timeOfDay = 'morning';
  bool _saving = false;

  final _times = ['morning', 'afternoon', 'evening', 'night'];

  @override
  void dispose() {
    _symptomCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_symptomCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final entry = SymptomEntry(
        id: const Uuid().v4(),
        userId: widget.uid,
        symptom: _symptomCtrl.text.trim(),
        severity: _severity,
        bodyLocation: _locationCtrl.text.trim(),
        timeOfDay: _timeOfDay,
        notes: _notesCtrl.text.trim(),
      );
      await widget.db.saveSymptom(widget.uid, entry);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
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
              const Text('Log Symptom',
                  style: AppTheme.headingSmall),
              const SizedBox(height: AppTheme.lg),
              TextField(
                controller: _symptomCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Symptom *',
                  hintText: 'e.g. Headache, Nausea, Chest pain',
                ),
              ),
              const SizedBox(height: AppTheme.md),
              TextField(
                controller: _locationCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Body Location (optional)',
                  hintText: 'e.g. Head, Chest, Abdomen',
                ),
              ),
              const SizedBox(height: AppTheme.lg),
              Text('Severity: $_severity/10',
                  style: AppTheme.labelLarge),
              Slider(
                value: _severity.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '$_severity',
                activeColor: _severity <= 3
                    ? AppTheme.successColor
                    : _severity <= 6
                        ? AppTheme.warningColor
                        : AppTheme.dangerColor,
                onChanged: (v) =>
                    setState(() => _severity = v.round()),
              ),
              const SizedBox(height: AppTheme.md),
              DropdownButtonFormField<String>(
                value: _timeOfDay,
                decoration:
                    const InputDecoration(labelText: 'Time of Day'),
                items: _times
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                              t[0].toUpperCase() + t.substring(1)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _timeOfDay = v!),
              ),
              const SizedBox(height: AppTheme.md),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Any additional details...',
                ),
              ),
              const SizedBox(height: AppTheme.xl),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
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
                    : const Text('Save Symptom',
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
