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
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : StreamBuilder<List<InsurancePolicy>>(
              stream: _policies(uid),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final policies = snap.data ?? [];

                return CustomScrollView(
                  slivers: [
                    // ── Header ──────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: _ScreenHeader(
                        policies: policies,
                        onClaimsTap: () =>
                            Navigator.pushNamed(context, AppRouter.claims),
                        onAddTap: () =>
                            Navigator.pushNamed(context, AppRouter.addPolicy),
                      ),
                    ),

                    if (policies.isEmpty)
                      const SliverFillRemaining(child: _EmptyState())
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              Text('Your Policies',
                                  style: AppTheme.headingSmall
                                      .copyWith(fontSize: 17)),
                              const Spacer(),
                              Text(
                                '${policies.length} total',
                                style: AppTheme.bodySmall
                                    .copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _PolicyCard(
                                policy: policies[i],
                                onEdit: () => Navigator.pushNamed(
                                    context, AppRouter.addPolicy,
                                    arguments: policies[i]),
                                onDelete: () =>
                                    db.deletePolicy(uid, policies[i].id),
                              ),
                            ),
                            childCount: policies.length,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),

      // ── Add Policy FAB ───────────────────────────────────────────────────
      floatingActionButton: _AddPolicyFab(
        onTap: () => Navigator.pushNamed(context, AppRouter.addPolicy),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ── Screen header (AppBar + Summary card combined) ───────────────────────────

class _ScreenHeader extends StatelessWidget {
  final List<InsurancePolicy> policies;
  final VoidCallback onClaimsTap;
  final VoidCallback onAddTap;

  const _ScreenHeader({
    required this.policies,
    required this.onClaimsTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final activePolicies = policies.where((p) => p.isActive).toList();
    final total =
        activePolicies.fold<double>(0, (s, p) => s + p.coverageAmount);
    final currency =
        activePolicies.isNotEmpty ? activePolicies.first.currencyCode : '';
    final active = activePolicies.length;
    final inactive = policies.length - active;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0055E5), Color(0xFF5856D6), Color(0xFFAF52DE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative blobs
          Positioned(
            right: -40, top: top,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            left: -30, top: top + 60,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 14, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    const Text('Insurance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        )),
                    const Spacer(),
                    _HeaderButton(
                      icon: Icons.receipt_long_rounded,
                      label: 'Claims',
                      onTap: onClaimsTap,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Coverage summary
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Coverage',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              )),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              policies.isEmpty
                                  ? '—'
                                  : formatMoney(total, currency),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              _StatPill(
                                  '$active active',
                                  const Color(0xFF34C759)),
                              if (inactive > 0)
                                _StatPill(
                                    '$inactive inactive',
                                    Colors.white.withValues(alpha: 0.3)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.5),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HeaderButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 15),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  )),
            ],
          ),
        ),
      );
}

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatPill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        ),
        child: Text(label,
            style: TextStyle(
              color: color == const Color(0xFF34C759) ? color : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            )),
      );
}

// ── Payment-card style Policy Card ───────────────────────────────────────────

class _PolicyCard extends StatelessWidget {
  final InsurancePolicy policy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PolicyCard({
    required this.policy,
    required this.onEdit,
    required this.onDelete,
  });

  // Vibrant two-stop gradients per policy type
  static const _typeGradients = <String, List<Color>>{
    'health': [Color(0xFF11998E), Color(0xFF38EF7D)],
    'term': [Color(0xFF4776E6), Color(0xFF8E54E9)],
    'critical_illness': [Color(0xFFFF416C), Color(0xFFFF4B2B)],
    'accidental': [Color(0xFFF7971E), Color(0xFFFFD200)],
    'other': [Color(0xFF6A11CB), Color(0xFF2575FC)],
  };

  // Overlapping circle colours (network badge, bottom-right of card)
  static const _networkColors = <String, List<Color>>{
    'health': [Color(0xFF38EF7D), Color(0xFF00B09B)],
    'term': [Color(0xFF8E54E9), Color(0xFF4776E6)],
    'critical_illness': [Color(0xFFFF4B2B), Color(0xFFFF416C)],
    'accidental': [Color(0xFFFFD200), Color(0xFFF7971E)],
    'other': [Color(0xFF2575FC), Color(0xFF6A11CB)],
  };

  static const _typeIcons = <String, IconData>{
    'health': Icons.favorite_rounded,
    'term': Icons.shield_rounded,
    'critical_illness': Icons.warning_rounded,
    'accidental': Icons.bolt_rounded,
    'other': Icons.policy_rounded,
  };

  static const _typeLabels = <String, String>{
    'health': 'Health Insurance',
    'term': 'Term Life',
    'critical_illness': 'Critical Illness',
    'accidental': 'Accidental',
    'other': 'Other',
  };

  static const _freqShort = <String, String>{
    'monthly': 'mo',
    'quarterly': 'qtr',
    'annual': 'yr',
  };

  @override
  Widget build(BuildContext context) {
    final colors = _typeGradients[policy.policyType] ?? _typeGradients['other']!;
    final netColors = _networkColors[policy.policyType] ?? _networkColors['other']!;
    final icon = _typeIcons[policy.policyType] ?? Icons.policy_rounded;
    final label = _typeLabels[policy.policyType] ?? 'Other';
    final freq = _freqShort[policy.premiumFrequency] ?? 'yr';
    final inactive = !policy.isActive;

    return Opacity(
      opacity: inactive ? 0.6 : 1.0,
      child: AspectRatio(
        // Standard payment card ratio 85.6 × 53.98 mm ≈ 1.586
        aspectRatio: 1.586,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: inactive
                ? null
                : [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.45),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              // ── Background texture — diagonal stripe pattern ─────────────
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomPaint(painter: _StripePainter()),
                ),
              ),

              // ── Large translucent circle (top-right) ────────────────────
              Positioned(
                right: -30, top: -30,
                child: Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),

              // ── Card content ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: type label + 3-dot menu
                    Row(
                      children: [
                        Icon(icon,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 15),
                        const SizedBox(width: 6),
                        Text(
                          inactive ? '$label  ·  Inactive' : label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 32, height: 32,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.more_horiz_rounded,
                                color: Colors.white.withValues(alpha: 0.8),
                                size: 20),
                            color: AppTheme.surfaceColor,
                            onSelected: (v) {
                              if (v == 'edit') onEdit();
                              if (v == 'delete') onDelete();
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete',
                                    style: TextStyle(
                                        color: AppTheme.dangerColor)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Policy number (card-number style)
                    Text(
                      _formatCardNumber(policy.policyNumber),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),

                    const Spacer(),

                    // Row 4 (bottom): insurer name + coverage / renewal + network logo
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Insurer
                              Text(
                                policy.insurer.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              // Coverage + renewal side by side
                              Row(
                                children: [
                                  _MiniStat(
                                    label: 'COVERAGE',
                                    value: formatMoney(policy.coverageAmount,
                                        policy.currencyCode),
                                  ),
                                  if (policy.renewalDate.isNotEmpty) ...[
                                    const SizedBox(width: 18),
                                    _MiniStat(
                                      label: 'VALID THRU',
                                      value: _shortDate(policy.renewalDate),
                                    ),
                                  ],
                                  if (policy.premiumAmount > 0) ...[
                                    const SizedBox(width: 18),
                                    _MiniStat(
                                      label: 'PREMIUM',
                                      value:
                                          '${formatMoney(policy.premiumAmount, policy.currencyCode)}/$freq',
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Mastercard-style overlapping circles
                        _NetworkLogo(colors: netColors),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Groups alphanumeric chars into blocks of 4, separated by spaces.
  String _formatCardNumber(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final buf = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write('  ');
      buf.write(clean[i]);
    }
    return buf.toString();
  }

  /// Returns MM/YY from an ISO date string, e.g. "2026-06-01" → "06/26".
  String _shortDate(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';
  }
}

// ── Card sub-widgets ──────────────────────────────────────────────────────────

/// Mastercard-style overlapping circles as a network logo.
class _NetworkLogo extends StatelessWidget {
  final List<Color> colors;
  const _NetworkLogo({required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52, height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors[0].withValues(alpha: 0.75),
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors[1].withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact two-line stat (label + value) used on the card bottom row.
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 1),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis),
        ],
      );
}

/// Subtle diagonal stripe texture painted on the card background.
class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke;

    const spacing = 28.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Floating Add Policy button ────────────────────────────────────────────────

class _AddPolicyFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPolicyFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0055E5), Color(0xFF5856D6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Add Policy',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0055E5), Color(0xFF5856D6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(height: 20),
        Text('No Policies Yet', style: AppTheme.headingSmall),
        const SizedBox(height: 8),
        Text(
          'Add your health, term or other insurance\npolicies to keep them all in one place.',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}
