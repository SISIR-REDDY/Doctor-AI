import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

abstract final class PatientDetailPalette {
  static const Color charcoal = Color(0xFF1E293B);
  static const Color slate = Color(0xFF334155);
  static const Color gold = Color(0xFFC9A227);
  static const Color goldMuted = Color(0xFFD4AF37);

  static const Color visit = Color(0xFF64748B);
  static const Color prescription = Color(0xFF047857);
  static const Color report = Color(0xFFB45309);
  static const Color foodAllergy = Color(0xFFEA580C);
  static const Color medAllergy = Color(0xFFBE123C);
  static const Color history = Color(0xFF6D28D9);

  static const Color actionConsult = Color(0xFF5B4FCF);
  static const Color actionNotes = Color(0xFF0D9488);
  static const Color actionScan = Color(0xFFC9A227);
}

abstract final class PatientSectionIds {
  static const lastVisit = 'lastVisit';
  static const prescriptions = 'prescriptions';
  static const reports = 'reports';
  static const foodAllergies = 'foodAllergies';
  static const medicinalAllergies = 'medicinalAllergies';
  static const medicalHistory = 'medicalHistory';
}

class PatientRecordSectionConfig {
  final String sectionId;
  final String title;
  final IconData icon;
  final Color accent;
  final List<String> values;
  final String emptyMessage;
  final bool isActive;
  final VoidCallback onTapSection;
  final Future<void> Function() onSaveSection;
  final TextEditingController? editController;
  final int editMaxLines;
  final List<String>? editList;
  final ValueChanged<List<String>>? onListChanged;

  const PatientRecordSectionConfig({
    required this.sectionId,
    required this.title,
    required this.icon,
    required this.accent,
    required this.values,
    required this.onTapSection,
    required this.onSaveSection,
    this.emptyMessage = 'Tap to add',
    this.isActive = false,
    this.editController,
    this.editMaxLines = 1,
    this.editList,
    this.onListChanged,
  });

  bool get isListEditor => editList != null && onListChanged != null;
}

class PatientRecordSection extends StatelessWidget {
  final PatientRecordSectionConfig config;

  const PatientRecordSection({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final items = config.values.where((v) => v.trim().isNotEmpty).toList();
    final isEmpty = items.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg, AppTheme.md),
      child: Material(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: config.isActive ? null : config.onTapSection,
          borderRadius: AppTheme.largeRadius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppTheme.largeRadius,
              border: Border.all(
                color: config.isActive
                    ? config.accent.withValues(alpha: 0.35)
                    : (isEmpty ? AppTheme.dividerColor : config.accent.withValues(alpha: 0.12)),
                width: config.isActive ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: config.accent.withValues(alpha: config.isActive ? 0.1 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(items.length, isEmpty),
                Divider(height: 1, color: config.accent.withValues(alpha: 0.08)),
                Padding(
                  padding: const EdgeInsets.all(AppTheme.lg),
                  child: config.isActive
                      ? _buildEditor(context)
                      : (isEmpty ? _buildEmptyHint() : _buildItems(items)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    if (config.isListEditor) return _buildListEditor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: config.editController,
          autofocus: true,
          maxLines: config.editMaxLines,
          style: AppTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: config.emptyMessage,
            filled: true,
            fillColor: config.accent.withValues(alpha: 0.04),
            border: OutlineInputBorder(borderRadius: AppTheme.smallRadius),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppTheme.smallRadius,
              borderSide: BorderSide(color: config.accent),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: config.onSaveSection,
            icon: Icon(Icons.check, color: config.accent, size: 18),
            label: Text('Done', style: TextStyle(color: config.accent, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildListEditor(BuildContext context) {
    final items = config.editList!;
    final onChanged = config.onListChanged!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('${config.sectionId}_${index}_${items.length}'),
                    initialValue: entry.value,
                    onChanged: (v) {
                      final updated = List<String>.from(items);
                      updated[index] = v;
                      onChanged(updated);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: config.accent.withValues(alpha: 0.04),
                      border: OutlineInputBorder(borderRadius: AppTheme.smallRadius),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: AppTheme.sm),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: config.accent, size: 20),
                  onPressed: () => onChanged(List<String>.from(items)..removeAt(index)),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => onChanged([...items, '']),
          icon: Icon(Icons.add, color: config.accent, size: 18),
          label: Text('Add entry', style: TextStyle(color: config.accent)),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: config.onSaveSection,
            icon: Icon(Icons.check, color: config.accent, size: 18),
            label: Text('Done', style: TextStyle(color: config.accent, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(int count, bool isEmpty) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.md, AppTheme.lg, AppTheme.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [config.accent.withValues(alpha: 0.06), config.accent.withValues(alpha: 0.02)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: config.accent.withValues(alpha: 0.12),
              borderRadius: AppTheme.smallRadius,
            ),
            child: Icon(config.icon, size: 20, color: config.accent),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Text(
              config.title,
              style: AppTheme.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: PatientDetailPalette.charcoal,
              ),
            ),
          ),
          if (config.isActive)
            Icon(Icons.edit, size: 18, color: config.accent)
          else if (!isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: config.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$count', style: TextStyle(color: config.accent, fontSize: 12, fontWeight: FontWeight.w700)),
            )
          else
            Icon(Icons.add_circle_outline, size: 20, color: config.accent.withValues(alpha: 0.6)),
        ],
      ),
    );
  }

  Widget _buildEmptyHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app_outlined, size: 18, color: config.accent.withValues(alpha: 0.7)),
        const SizedBox(width: AppTheme.sm),
        Text(
          config.emptyMessage,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textTertiary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildItems(List<String> items) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final isLast = entry.key == items.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : AppTheme.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                margin: const EdgeInsets.only(top: 8),
                height: 20,
                decoration: BoxDecoration(
                  color: config.accent.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Text(
                  entry.value,
                  style: AppTheme.bodyMedium.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class PatientQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const PatientQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.mediumRadius,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: 0.08), accent.withValues(alpha: 0.03)],
            ),
            borderRadius: AppTheme.mediumRadius,
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.lg),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(height: AppTheme.sm),
                Text(
                  label,
                  style: const TextStyle(
                    color: PatientDetailPalette.charcoal,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
