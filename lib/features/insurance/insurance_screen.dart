import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/insurance_regions.dart';
import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';

class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key});

  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> {
  final db = FirestoreService();

  // Cache the stream so rebuilds (e.g. theme toggle) don't resubscribe/reload.
  Stream<List<InsurancePolicy>>? _stream;
  String? _streamUid;
  Stream<List<InsurancePolicy>> _policies(String uid) {
    if (_streamUid != uid) {
      _streamUid = uid;
      _stream = db.watchPolicies(uid);
    }
    return _stream!;
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<HealthDataProvider>().uid;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Insurance Policies'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text('Claims'),
            onPressed: () =>
                Navigator.pushNamed(context, AppRouter.claims),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : StreamBuilder<List<InsurancePolicy>>(
              stream: _policies(uid),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final policies = snap.data ?? [];

                if (policies.isEmpty) {
                  return _EmptyState();
                }

                return ListView(
                  padding: const EdgeInsets.all(AppTheme.lg),
                  children: [
                    _SummaryCard(policies: policies),
                    const SizedBox(height: AppTheme.lg),
                    Text('Your Policies',
                        style:
                            AppTheme.headingSmall.copyWith(fontSize: 17)),
                    const SizedBox(height: AppTheme.md),
                    ...policies.map((p) => _PolicyCard(
                          policy: p,
                          onEdit: () => Navigator.pushNamed(
                              context, AppRouter.addPolicy,
                              arguments: p),
                          onDelete: () => db.deletePolicy(uid, p.id),
                        )),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.pushNamed(context, AppRouter.addPolicy),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Policy'),
        backgroundColor: AppTheme.warningColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final List<InsurancePolicy> policies;
  const _SummaryCard({required this.policies});

  @override
  Widget build(BuildContext context) {
    final activePolicies = policies.where((p) => p.isActive).toList();
    final active = activePolicies.length;
    final totalCoverage =
        activePolicies.fold<double>(0, (sum, p) => sum + p.coverageAmount);
    // Coverage may span policies in different currencies; format the headline
    // total using the first active policy's currency (best-effort).
    final headerCurrency =
        activePolicies.isNotEmpty ? activePolicies.first.currencyCode : '';

    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: BoxDecoration(
        gradient: AppTheme.warningGradient,
        borderRadius: AppTheme.largeRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Coverage',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(
                  formatMoney(totalCoverage, headerCurrency),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text('$active active polic${active == 1 ? 'y' : 'ies'}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded,
                color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }
}

// ── Policy Card ───────────────────────────────────────────────────────────────

class _PolicyCard extends StatelessWidget {
  final InsurancePolicy policy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PolicyCard(
      {required this.policy,
      required this.onEdit,
      required this.onDelete});

  static Map<String, Color> get _typeColors => <String, Color>{
    'health': AppTheme.successColor,
    'term': AppTheme.infoColor,
    'critical_illness': AppTheme.dangerColor,
    'accidental': AppTheme.warningColor,
    'other': AppTheme.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final color =
        _typeColors[policy.policyType] ?? AppTheme.textSecondary;

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
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _typeLabel(policy.policyType),
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              if (!policy.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Inactive',
                      style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: AppTheme.textTertiary, size: 20),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style:
                            TextStyle(color: AppTheme.dangerColor)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(policy.insurer,
              style: AppTheme.bodyMedium
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 17)),
          Text('Policy No: ${policy.policyNumber}',
              style: AppTheme.bodySmall),
          const SizedBox(height: AppTheme.md),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Coverage',
                  value: formatMoney(policy.coverageAmount, policy.currencyCode),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Premium',
                  value:
                      '${formatMoney(policy.premiumAmount, policy.currencyCode)}/${_shortFreq(policy.premiumFrequency)}',
                ),
              ),
              if (policy.renewalDate.isNotEmpty)
                Expanded(
                  child: _Stat(
                    label: 'Renewal',
                    value: policy.renewalDate,
                  ),
                ),
            ],
          ),
          if (policy.nomineeName.isNotEmpty) ...[
            const SizedBox(height: AppTheme.sm),
            Row(
              children: [
                Icon(Icons.person_pin_outlined,
                    size: 14, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text(
                    'Nominee: ${policy.nomineeName} (${policy.nomineeRelation})',
                    style: AppTheme.bodySmall),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    const labels = {
      'health': 'Health',
      'term': 'Term Life',
      'critical_illness': 'Critical Illness',
      'accidental': 'Accidental',
      'other': 'Other',
    };
    return labels[type] ?? type;
  }

  String _shortFreq(String f) {
    const m = {'monthly': 'mo', 'quarterly': 'qtr', 'annual': 'yr'};
    return m[f] ?? f;
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.bodySmall),
        Text(value,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
      ],
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
          Icon(Icons.shield_outlined,
              size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: AppTheme.lg),
          Text('No insurance policies added',
              style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.sm),
          Text('Add your health or term insurance policies\nto keep them organised',
              style: AppTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
