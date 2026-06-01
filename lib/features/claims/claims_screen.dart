import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/insurance_regions.dart';
import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';

class ClaimsScreen extends StatelessWidget {
  const ClaimsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<HealthDataProvider>().uid;
    final db = FirestoreService();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Insurance Claims')),
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : StreamBuilder<List<InsuranceClaim>>(
              stream: db.watchClaims(uid),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final claims = snap.data ?? [];
                if (claims.isEmpty) {
                  return _EmptyState();
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.lg),
                  itemCount: claims.length,
                  itemBuilder: (_, i) => _ClaimCard(
                    claim: claims[i],
                    onTap: () => Navigator.pushNamed(
                        context, AppRouter.claimDetail,
                        arguments: claims[i]),
                    onDelete: () =>
                        db.deleteClaim(uid, claims[i].id),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.pushNamed(context, AppRouter.newClaim),
        icon: const Icon(Icons.add_rounded),
        label: const Text('File Claim'),
        backgroundColor: AppTheme.infoColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ── Claim Card ────────────────────────────────────────────────────────────────

class _ClaimCard extends StatelessWidget {
  final InsuranceClaim claim;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _ClaimCard(
      {required this.claim, required this.onTap, required this.onDelete});

  static const _statusColors = <String, Color>{
    'pending': AppTheme.warningColor,
    'approved': AppTheme.successColor,
    'rejected': AppTheme.dangerColor,
    'under_review': AppTheme.infoColor,
  };

  static const _statusIcons = <String, IconData>{
    'pending': Icons.schedule_rounded,
    'approved': Icons.check_circle_rounded,
    'rejected': Icons.cancel_rounded,
    'under_review': Icons.pending_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color =
        _statusColors[claim.claimStatus] ?? AppTheme.textSecondary;
    final icon = _statusIcons[claim.claimStatus] ?? Icons.help_outline;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.md),
        padding: const EdgeInsets.all(AppTheme.lg),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(
            color: claim.isRejected
                ? AppTheme.dangerColor.withValues(alpha: 0.3)
                : AppTheme.dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  _statusLabel(claim.claimStatus),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  formatMoney(claim.effectiveAmount, claim.currencyCode),
                  style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: AppTheme.textTertiary, size: 18),
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(
                                color: AppTheme.dangerColor))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sm),
            if (claim.title.isNotEmpty)
              Text(claim.title,
                  style: AppTheme.bodyMedium
                      .copyWith(fontWeight: FontWeight.w700)),
            Text(claim.insurer,
                style: AppTheme.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            if (claim.hospitalName.isNotEmpty)
              Text(claim.hospitalName, style: AppTheme.bodySmall),
            if (claim.diagnosis.isNotEmpty)
              Text('Diagnosis: ${claim.diagnosis}',
                  style: AppTheme.bodySmall),
            if (claim.expenses.isNotEmpty)
              Text(
                  '${claim.expenses.length} bill${claim.expenses.length == 1 ? '' : 's'}',
                  style: AppTheme.labelSmall),
            const SizedBox(height: AppTheme.sm),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 12, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text(
                    DateFormat('dd MMM yyyy')
                        .format(claim.createdAt),
                    style: AppTheme.bodySmall.copyWith(fontSize: 11)),
                if (claim.isRejected) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gavel_rounded,
                            color: AppTheme.dangerColor, size: 12),
                        SizedBox(width: 4),
                        Text('Fight →',
                            style: TextStyle(
                                color: AppTheme.dangerColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    const labels = {
      'pending': 'Pending',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'under_review': 'Under Review',
    };
    return labels[s] ?? s;
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
          Icon(Icons.receipt_long_outlined,
              size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: AppTheme.lg),
          Text('No claims filed yet', style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.sm),
          Text(
              'File insurance claims and track their\nstatus here. We\'ll help you fight rejections.',
              style: AppTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
