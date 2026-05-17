import 'package:flutter/material.dart';

import '../../core/healthcare/consultation_ui_theme.dart';
import '../../models/health_models.dart';
import '../../theme/app_theme.dart';

class ClinicalNoteCard extends StatelessWidget {
  final ClinicalNote note;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ClinicalNoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  bool get _isVoiceNote => note.noteType == 'voice';

  Color _diagnosisColor(String? diagnosis) {
    if (diagnosis == null || diagnosis.trim().isEmpty) {
      return ConsultationPalette.muted;
    }
    final lower = diagnosis.toLowerCase();
    if (lower.contains('severe') || lower.contains('critical') || lower.contains('urgent')) {
      return AppTheme.dangerColor;
    }
    if (lower.contains('moderate') || lower.contains('warning')) {
      return ConsultationPalette.warning;
    }
    if (lower.contains('healthy') || lower.contains('normal')) {
      return ConsultationPalette.prescription;
    }
    return ConsultationPalette.summary;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today • ${_time(date)}';
    if (diff.inDays == 1) return 'Yesterday • ${_time(date)}';
    if (diff.inDays < 7) return '${diff.inDays}d ago • ${_time(date)}';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _time(DateTime date) {
    final h = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final m = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final diagnosis = note.diagnosis?.trim();
    final hasDiagnosis = diagnosis != null && diagnosis.isNotEmpty;
    final preview = note.content.trim();
    final wordCount = preview.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return Material(
      color: ConsultationPalette.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ConsultationPalette.cream),
            boxShadow: [
              BoxShadow(
                color: ConsultationPalette.charcoal.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppTheme.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (_isVoiceNote ? ConsultationPalette.transcript : ConsultationPalette.summary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isVoiceNote ? Icons.mic_rounded : Icons.description_outlined,
                      color: _isVoiceNote ? ConsultationPalette.transcript : ConsultationPalette.summary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title.isEmpty ? 'Clinical Note' : note.title,
                          style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${note.createdBy} • ${_formatDate(note.createdAt)}',
                          style: AppTheme.bodySmall.copyWith(color: ConsultationPalette.muted),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: ConsultationPalette.muted.withValues(alpha: 0.8)),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: AppTheme.dangerColor)),
                      ),
                    ],
                  ),
                ],
              ),
              if (hasDiagnosis) ...[
                const SizedBox(height: AppTheme.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: AppTheme.xs),
                  decoration: BoxDecoration(
                    color: _diagnosisColor(diagnosis).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.medical_information_outlined, size: 14, color: _diagnosisColor(diagnosis)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          diagnosis,
                          style: AppTheme.labelSmall.copyWith(
                            color: _diagnosisColor(diagnosis),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (preview.isNotEmpty) ...[
                const SizedBox(height: AppTheme.md),
                Text(
                  preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySmall.copyWith(height: 1.45, color: ConsultationPalette.ink),
                ),
              ],
              const SizedBox(height: AppTheme.md),
              Row(
                children: [
                  _metaChip(Icons.text_snippet_outlined, '$wordCount words'),
                  if (note.treatments.isNotEmpty) ...[
                    const SizedBox(width: AppTheme.sm),
                    _metaChip(Icons.medication_outlined, '${note.treatments.length} tx'),
                  ],
                  if (note.followUpItems.isNotEmpty) ...[
                    const SizedBox(width: AppTheme.sm),
                    _metaChip(Icons.event_note_outlined, '${note.followUpItems.length} follow-up'),
                  ],
                  if (_isVoiceNote) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ConsultationPalette.transcript.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Voice',
                        style: AppTheme.labelSmall.copyWith(
                          color: ConsultationPalette.transcript,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ConsultationPalette.muted),
        const SizedBox(width: 4),
        Text(label, style: AppTheme.labelSmall.copyWith(color: ConsultationPalette.muted)),
      ],
    );
  }
}
