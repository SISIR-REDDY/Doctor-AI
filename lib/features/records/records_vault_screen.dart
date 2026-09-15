
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/advocate_models.dart';
import '../../models/patient_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/ios18_components.dart';
import '../scan/document_scan_screen.dart';

class RecordsVaultScreen extends StatefulWidget {
  const RecordsVaultScreen({super.key});

  @override
  State<RecordsVaultScreen> createState() => _RecordsVaultScreenState();
}

class _RecordsVaultScreenState extends State<RecordsVaultScreen> {
  final _db = FirestoreService();
  String _filterType = 'All';
  String _query = '';

  // Tracks record ids we've already tried to re-sync this session so the
  // background retry doesn't fire repeatedly on every stream emission.
  final Set<String> _retriedIds = {};

  /// Best-effort: re-upload any record that's still local-only. Runs quietly in
  /// the background and persists the resulting cloud URLs back to Firestore.
  Future<void> _resyncPending(String uid, List<MedicalRecord> records) async {
    final pending = records.where((r) =>
        !r.isSynced &&
        r.localImagePaths.isNotEmpty &&
        !_retriedIds.contains(r.id));
    for (final r in pending) {
      _retriedIds.add(r.id);
      try {
        final urls = await StorageService().retryUpload(
          localPaths: r.localImagePaths,
          patientId: uid,
          recordId: r.id,
        );
        if (urls.length >= r.localImagePaths.length) {
          await _db.saveMedicalRecord(
            uid,
            r.copyWith(
              imageUrl: urls.first,
              imageUrls: urls,
              isSynced: true,
            ),
          );
        }
      } catch (_) {
        // Stay local; will retry next session.
      }
    }
  }

  // Cache the stream so rebuilds (e.g. theme toggle) don't resubscribe/reload.
  Stream<List<MedicalRecord>>? _stream;
  String? _streamUid;
  Stream<List<MedicalRecord>> _records(String uid) {
    if (_streamUid != uid) {
      _streamUid = uid;
      _stream = _db.watchMedicalRecords(uid);
    }
    return _stream!;
  }

  static const _types = [
    'All',
    'lab',
    'imaging',
    'prescription',
    'discharge',
    'vaccination',
    'other',
  ];

  static const _typeLabels = {
    'All': 'All',
    'lab': 'Lab Reports',
    'imaging': 'Imaging',
    'prescription': 'Prescriptions',
    'discharge': 'Discharge',
    'vaccination': 'Vaccination',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    final uid = context.read<HealthDataProvider>().uid;

    return LargeTitleScaffold(
      title: 'Records',
      subtitle: 'Your medical documents, summarized by AI',
      floatingActionButton: uid == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => DocumentScanScreen.open(context, trigger: 'records', docType: DocType.record),
              icon: const Icon(Icons.document_scanner_rounded),
              label: const Text('Scan'),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
      slivers: [
        if (uid == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Please sign in')),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DS.gutter, 4, DS.gutter, 4),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search records, results, values…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: DS.squircle(14),
                    borderSide: BorderSide(color: AppTheme.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: DS.squircle(14),
                    borderSide: BorderSide(color: AppTheme.glassBorder),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _TypeFilter(
              types: _types,
              labels: _typeLabels,
              selected: _filterType,
              onChanged: (t) => setState(() => _filterType = t),
            ),
          ),
          StreamBuilder<List<MedicalRecord>>(
            stream: _records(uid),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final all = snap.data ?? [];
              // Quietly retry cloud upload for any local-only records.
              if (all.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _resyncPending(uid, all));
              }
              var filtered = _filterType == 'All'
                  ? all
                  : all.where((r) => r.recordType == _filterType).toList();
              if (_query.isNotEmpty) {
                final q = _query.toLowerCase();
                filtered = filtered.where((r) {
                  return r.title.toLowerCase().contains(q) ||
                      r.extractedText.toLowerCase().contains(q) ||
                      r.aiSummary.toLowerCase().contains(q);
                }).toList();
              }

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    message: _query.isNotEmpty
                        ? 'No records match "$_query".'
                        : _filterType == 'All'
                            ? 'No records yet.\nTap Scan to add a document.'
                            : 'No ${_typeLabels[_filterType]} records.',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    DS.gutter, 4, DS.gutter, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecordCard(
                        record: filtered[i],
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRouter.recordDetail,
                          arguments: filtered[i],
                        ),
                        onDelete: () =>
                            _db.deleteMedicalRecord(uid, filtered[i].id),
                      ),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

// ── Type Filter ───────────────────────────────────────────────────────────────

class _TypeFilter extends StatelessWidget {
  final List<String> types;
  final Map<String, String> labels;
  final String selected;
  final ValueChanged<String> onChanged;

  const _TypeFilter({
    required this.types,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(DS.gutter, 6, DS.gutter, 10),
        itemCount: types.length,
        itemBuilder: (_, i) {
          final t = types[i];
          final selected = this.selected == t;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DSPressable(
              onTap: () => onChanged(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.surfaceColor,
                  borderRadius: DS.squircle(20),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primaryColor
                        : AppTheme.glassBorder,
                    width: 0.7,
                  ),
                  boxShadow: selected ? null : DS.softShadow(y: 2, blur: 8),
                ),
                child: Text(
                  labels[t] ?? t,
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Record Card ───────────────────────────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  final MedicalRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _RecordCard(
      {required this.record,
      required this.onTap,
      required this.onDelete});

  static Map<String, Color> get _typeColors => <String, Color>{
    'lab': AppTheme.infoColor,
    'imaging': AppTheme.neurologyColor,
    'prescription': AppTheme.surgeryColor,
    'discharge': AppTheme.warningColor,
    'vaccination': AppTheme.secondaryColor,
    'other': AppTheme.textSecondary,
  };

  static const _typeIcons = <String, IconData>{
    'lab': Icons.science_outlined,
    'imaging': Icons.medical_information_outlined,
    'prescription': Icons.medication_outlined,
    'discharge': Icons.local_hospital_outlined,
    'vaccination': Icons.vaccines_outlined,
    'other': Icons.description_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[record.recordType] ?? AppTheme.textSecondary;
    final icon = _typeIcons[record.recordType] ?? Icons.description_outlined;

    return DSPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.lg),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: DS.squircle(DS.rLg),
          border: Border.all(color: AppTheme.glassBorder, width: 0.7),
          boxShadow: DS.softShadow(),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: DS.squircle(13),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.title.isEmpty ? 'Medical Record' : record.title,
                      style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          record.recordType[0].toUpperCase() +
                              record.recordType.substring(1),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM yyyy')
                            .format(record.uploadedAt),
                        style: AppTheme.bodySmall.copyWith(fontSize: 11),
                      ),
                      if (!record.isSynced &&
                          record.localImagePaths.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.warningColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_off_rounded,
                                  size: 10, color: AppTheme.warningColor),
                              const SizedBox(width: 3),
                              Text('On device',
                                  style: TextStyle(
                                      color: AppTheme.warningColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (record.isProcessed && record.aiSummary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        record.aiSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodySmall
                            .copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: AppTheme.textTertiary, size: 20),
              onSelected: (v) {
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: AppTheme.dangerColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_rounded,
              size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: AppTheme.lg),
          Text(message,
              style: AppTheme.bodyMedium
                  .copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
