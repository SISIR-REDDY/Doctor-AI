import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/insurance_regions.dart';
import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/advocate_models.dart';
import '../../models/patient_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../core/errors/app_error_handler.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';
import '../scan/document_scan_screen.dart';

/// "Cases" — every bill, claim and appeal the user is working on.
class ClaimsScreen extends StatefulWidget {
  /// True when shown as a tab (no back button, extra bottom inset).
  final bool embedded;
  const ClaimsScreen({super.key, this.embedded = false});

  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  final _db = FirestoreService();
  String? _uid;
  Stream<List<InsuranceClaim>>? _stream;
  String _filter = 'open';

  Stream<List<InsuranceClaim>>? _claims(String? uid) {
    if (uid == null) return null;
    if (uid != _uid) {
      _uid = uid;
      _stream = _db.watchClaims(uid);
    }
    return _stream;
  }

  Future<void> _delete(String uid, InsuranceClaim c) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete this case?'),
        content: const Text('Bills, audits and letters in this case will be removed.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteDeadlinesForCase(uid, c.id);
      await _db.deleteClaim(uid, c.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<HealthDataProvider>().uid;
    final stream = _claims(uid);

    return LargeTitleScaffold(
      title: 'Cases',
      subtitle: 'Bills, claims and appeals — and the money in each',
      automaticallyImplyLeading: !widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => DocumentScanScreen.open(context, trigger: 'cases'),
        icon: const Icon(CupertinoIcons.camera_viewfinder),
        label: const Text('Scan'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      slivers: [
        if (uid == null || stream == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Please sign in')),
          )
        else
          StreamBuilder<List<InsuranceClaim>>(
            stream: stream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }
              final all = snap.data ?? const <InsuranceClaim>[];
              if (all.isEmpty) {
                return SliverFillRemaining(hasScrollBody: false, child: _EmptyState());
              }
              final claims = all.where((c) => _filter == 'open' ? !c.isClosed : c.isClosed).toList();
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(DS.gutter, 4, DS.gutter, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _Filter(
                      value: _filter,
                      openCount: all.where((c) => !c.isClosed).length,
                      closedCount: all.where((c) => c.isClosed).length,
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                    const SizedBox(height: 12),
                    if (claims.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            _filter == 'open' ? 'No open cases' : 'No closed cases yet',
                            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    for (final c in claims)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CaseCard(
                          claim: c,
                          onTap: () => Navigator.pushNamed(context, AppRouter.claimDetail, arguments: c),
                          onDelete: () => runGuarded(context, () => _delete(uid, c)),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pushNamed(context, AppRouter.newClaim),
                        icon: const Icon(CupertinoIcons.plus, size: 16),
                        label: const Text('Create a case manually'),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _Filter extends StatelessWidget {
  final String value;
  final int openCount;
  final int closedCount;
  final ValueChanged<String> onChanged;
  const _Filter({required this.value, required this.openCount, required this.closedCount, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<String>(
      groupValue: value,
      backgroundColor: AppTheme.surfaceVariant,
      thumbColor: AppTheme.surfaceColor,
      onValueChanged: (v) => onChanged(v ?? 'open'),
      children: {
        'open': Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('Open ($openCount)', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ),
        'closed': Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('Closed ($closedCount)', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ),
      },
    );
  }
}

// ── Case card ─────────────────────────────────────────────────────────────────

class _CaseCard extends StatelessWidget {
  final InsuranceClaim claim;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _CaseCard({required this.claim, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cur = claim.currencyCode;
    final title = claim.title.isNotEmpty
        ? claim.title
        : claim.hospitalName.isNotEmpty
            ? claim.hospitalName
            : claim.insurer.isNotEmpty
                ? claim.insurer
                : 'Untitled case';
    final accent = claim.isClosed
        ? (claim.outcomeStatus == OutcomeStatus.won || claim.outcomeStatus == OutcomeStatus.partial
            ? AppTheme.successColor
            : AppTheme.textTertiary)
        : claim.hasDenial
            ? AppTheme.warningColor
            : AppTheme.primaryColor;
    final icon = claim.hasDenial ? CupertinoIcons.xmark_shield_fill : CupertinoIcons.doc_text_fill;
    final subtitleParts = <String>[
      if (claim.insurer.isNotEmpty) claim.insurer,
      if (claim.hospitalName.isNotEmpty && claim.hospitalName != title) claim.hospitalName,
      if (claim.expenses.isNotEmpty) '${claim.expenses.length} ${claim.expenses.length == 1 ? 'bill' : 'bills'}',
    ];

    return DSPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: DS.squircle(DS.rLg),
          border: Border.all(color: AppTheme.glassBorder, width: 0.7),
          boxShadow: DS.softShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(icon, color: accent, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      if (subtitleParts.isNotEmpty)
                        Text(subtitleParts.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(CupertinoIcons.ellipsis, color: AppTheme.textTertiary, size: 18),
                    onSelected: (v) {
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('Delete case', style: TextStyle(color: AppTheme.dangerColor))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    compact: true,
                    label: claim.isClosed ? 'Recovered' : 'Potential savings',
                    value: claim.isClosed
                        ? formatMoney(claim.totalRecovered, cur)
                        : claim.potentialSaving > 0
                            ? formatMoney(claim.potentialSaving, cur)
                            : '—',
                    foreground: claim.isClosed || claim.potentialSaving > 0 ? AppTheme.successColor : null,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    compact: true,
                    label: claim.hasDenial ? 'Denied amount' : 'Billed',
                    value: claim.hasDenial && claim.denial!.amountDenied > 0
                        ? formatMoney(claim.denial!.amountDenied, cur)
                        : claim.effectiveAmount > 0
                            ? formatMoney(claim.effectiveAmount, cur)
                            : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Pill(
                  claim.isClosed ? OutcomeStatus.label(claim.outcomeStatus) : claim.nextAction,
                  color: accent,
                  icon: claim.isClosed ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.arrow_right_circle_fill,
                ),
                const Spacer(),
                Text(DateFormat('d MMM yyyy').format(claim.updatedAt),
                    style: AppTheme.bodySmall.copyWith(fontSize: 11, color: AppTheme.textTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(CupertinoIcons.briefcase_fill, color: AppTheme.primaryColor, size: 72),
          const SizedBox(height: 18),
          Text('No cases yet', style: AppTheme.headingMedium),
          const SizedBox(height: 8),
          Text(
            'Scan a bill, an insurer statement or a denial letter. Clinix creates the case, audits it and drafts what to send.',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          HeroButton(
            label: 'Scan a document',
            icon: CupertinoIcons.camera_viewfinder,
            onTap: () => DocumentScanScreen.open(context, trigger: 'cases_empty'),
          ),
        ],
      ),
    );
  }
}
