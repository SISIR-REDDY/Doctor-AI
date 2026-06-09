import 'package:flutter/material.dart';

import '../../core/config/legal_content.dart';
import '../../theme/app_theme.dart';
import '../../theme/ios18_components.dart';
import 'legal_screens.dart';

/// First-run blocking consent gate. The user MUST read the disclaimers and tick
/// the checkbox before they can continue to sign-in — required for App Review
/// (Guideline 1.4.1 physical harm) and to reduce liability.
class ConsentGateScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  const ConsentGateScreen({super.key, required this.onAccepted});

  @override
  State<ConsentGateScreen> createState() => _ConsentGateScreenState();
}

class _ConsentGateScreenState extends State<ConsentGateScreen> {
  bool _agreed = false;

  void _openDoc(LegalDoc doc) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LegalDocumentScreen(doc: doc)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(DS.gutter, 24, DS.gutter, 8),
                children: [
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: DS.squircle(18),
                      ),
                      child: const Icon(Icons.health_and_safety_rounded,
                          color: Colors.white, size: 32),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Before you start',
                      textAlign: TextAlign.center,
                      style: AppTheme.headingLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Please read and accept the following. Clinix AI helps you '
                    'organize your health and insurance — it does not replace '
                    'professional care or advice.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 22),
                  _DisclaimerCard(
                    icon: Icons.medical_information_outlined,
                    color: AppTheme.dangerColor,
                    title: 'Not medical advice',
                    body: AppLegal.medicalDisclaimerShort,
                  ),
                  _DisclaimerCard(
                    icon: Icons.gavel_outlined,
                    color: AppTheme.warningColor,
                    title: 'Not legal or financial advice',
                    body: AppLegal.insuranceDisclaimerShort,
                  ),
                  _DisclaimerCard(
                    icon: Icons.cloud_outlined,
                    color: AppTheme.primaryColor,
                    title: 'AI processing',
                    body: AppLegal.aiDataNotice,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    children: [
                      _DocLink('Privacy Policy',
                          () => _openDoc(LegalDoc.privacy)),
                      _DocLink('Terms of Use', () => _openDoc(LegalDoc.terms)),
                      _DocLink('Medical Disclaimer',
                          () => _openDoc(LegalDoc.medical)),
                      _DocLink('Insurance Disclaimer',
                          () => _openDoc(LegalDoc.insurance)),
                    ],
                  ),
                ],
              ),
            ),
            // Sticky consent footer.
            Container(
              padding: const EdgeInsets.fromLTRB(DS.gutter, 12, DS.gutter, 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(
                    top: BorderSide(color: AppTheme.glassBorder, width: 0.7)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => setState(() => _agreed = !_agreed),
                    borderRadius: DS.squircle(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreed,
                            onChanged: (v) =>
                                setState(() => _agreed = v ?? false),
                            activeColor: AppTheme.primaryColor,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 11),
                              child: Text(
                                'I understand Clinix AI does not provide medical, '
                                'legal, or financial advice, and I agree to the '
                                'Terms of Use and Privacy Policy.',
                                style: AppTheme.bodySmall.copyWith(height: 1.35),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DSButton(
                    label: 'Agree & Continue',
                    onTap: _agreed ? widget.onAccepted : null,
                    color: _agreed
                        ? AppTheme.primaryColor
                        : AppTheme.textTertiary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _DisclaimerCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DS.squircle(DS.rLg),
        border: Border.all(color: AppTheme.glassBorder, width: 0.7),
        boxShadow: DS.softShadow(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: DS.squircle(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTheme.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(body,
                    style: AppTheme.bodySmall.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DocLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          )),
    );
  }
}
