import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/legal_content.dart';
import '../../theme/app_theme.dart';
import '../../theme/ios18_components.dart';

/// Which legal document to display.
enum LegalDoc { privacy, terms, medical, insurance }

extension LegalDocData on LegalDoc {
  String get title => switch (this) {
        LegalDoc.privacy => 'Privacy Policy',
        LegalDoc.terms => 'Terms of Use',
        LegalDoc.medical => 'Medical Disclaimer',
        LegalDoc.insurance => 'Insurance Disclaimer',
      };

  String get body => switch (this) {
        LegalDoc.privacy => AppLegal.privacyPolicy,
        LegalDoc.terms => AppLegal.termsOfUse,
        LegalDoc.medical => AppLegal.medicalDisclaimer,
        LegalDoc.insurance => AppLegal.insuranceDisclaimer,
      };

  /// Hosted URL for this doc, if configured (privacy/terms only).
  String? get hostedUrl => switch (this) {
        LegalDoc.privacy => AppLegal.hasPrivacyUrl ? AppLegal.privacyPolicyUrl : null,
        LegalDoc.terms => AppLegal.hasTermsUrl ? AppLegal.termsUrl : null,
        _ => null,
      };
}

/// Renders one legal document. If a hosted URL is configured it offers to open
/// it externally, but always shows the bundled text so the content is reachable
/// offline and during App Review.
class LegalDocumentScreen extends StatelessWidget {
  final LegalDoc doc;
  const LegalDocumentScreen({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final url = doc.hostedUrl;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(doc.title),
        actions: [
          if (url != null)
            IconButton(
              tooltip: 'Open online',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication),
            ),
        ],
      ),
      body: Markdown(
        data: doc.body,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        styleSheet: MarkdownStyleSheet(
          h1: AppTheme.headingMedium,
          h2: AppTheme.headingSmall.copyWith(color: AppTheme.primaryColor),
          p: AppTheme.bodyMedium.copyWith(height: 1.55),
          listBullet: AppTheme.bodyMedium,
          strong: AppTheme.bodyMedium
              .copyWith(fontWeight: FontWeight.w700, height: 1.55),
        ),
      ),
    );
  }
}

/// "Legal & Privacy" hub — links to every document. Lives in Profile.
class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  void _open(BuildContext context, LegalDoc doc) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LegalDocumentScreen(doc: doc)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Legal & Privacy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DS.gutter, 16, DS.gutter, 40),
        children: [
          InsetSection(
            header: 'Your rights',
            children: [
              InsetRow(
                icon: Icons.privacy_tip_outlined,
                iconColor: AppTheme.primaryColor,
                title: 'Privacy Policy',
                subtitle: 'What we collect and how it is used',
                onTap: () => _open(context, LegalDoc.privacy),
              ),
              InsetRow(
                icon: Icons.description_outlined,
                iconColor: AppTheme.secondaryColor,
                title: 'Terms of Use',
                onTap: () => _open(context, LegalDoc.terms),
              ),
            ],
          ),
          InsetSection(
            header: 'Important disclaimers',
            footer:
                'Clinix AI is not a medical device and does not provide medical, '
                'legal, or financial advice.',
            children: [
              InsetRow(
                icon: Icons.medical_information_outlined,
                iconColor: AppTheme.dangerColor,
                title: 'Medical Disclaimer',
                subtitle: 'Not a substitute for professional care',
                onTap: () => _open(context, LegalDoc.medical),
              ),
              InsetRow(
                icon: Icons.gavel_outlined,
                iconColor: AppTheme.warningColor,
                title: 'Insurance Disclaimer',
                subtitle: 'Not legal or financial advice',
                onTap: () => _open(context, LegalDoc.insurance),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
