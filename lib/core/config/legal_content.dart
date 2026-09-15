/// Centralized legal & compliance copy for Clinix AI.
///
/// IMPORTANT: This text is a good-faith, comprehensive starting point written to
/// satisfy App Store Review (Guidelines 1.4.1, 5.1.1) and reduce liability. It is
/// **not** a substitute for review by a qualified attorney in each market you
/// ship to. Have counsel review before public launch.
///
/// [AppLegal.privacyPolicyUrl] / [AppLegal.termsUrl] are optional hosted-document
/// slots — when set, the app links out to them; otherwise it shows the bundled
/// in-app text below.
class AppLegal {
  AppLegal._();

  /// Bump when the legal terms materially change. Stored against the user's
  /// acceptance so you can re-prompt for consent after an update.
  static const int consentVersion = 2;

  static const String companyName = 'Clinix AI';
  static const String contactEmail = 'calorievita.dev@gmail.com';

  /// Optional hosted URLs. Leave empty to use the bundled in-app documents.
  static const String privacyPolicyUrl = '';
  static const String termsUrl = '';

  static bool get hasPrivacyUrl => privacyPolicyUrl.isNotEmpty;
  static bool get hasTermsUrl => termsUrl.isNotEmpty;

  // ── Short disclaimers (shown inline / on consent gate) ──────────────────────

  static const String medicalDisclaimerShort =
      'Clinix AI provides general health information and is NOT a substitute for '
      'professional medical advice, diagnosis, or treatment. It is not a medical '
      'device and does not diagnose conditions. Always consult a qualified '
      'healthcare provider. In an emergency, call your local emergency number '
      'immediately.';

  static const String insuranceDisclaimerShort =
      'Insurance and claim guidance in Clinix AI is general information only and '
      'is NOT legal, financial, or professional advice. AI-generated reports, '
      'letters, and appeals may contain errors — review everything and consult a '
      'qualified professional before relying on or submitting it.';

  static const String aiDataNotice =
      'To analyze documents and answer questions, Clinix sends the content you '
      'choose to share (document images or PDFs, text, and voice) through our '
      'own servers to third-party AI providers (Google Gemini on a paid tier '
      'whose terms exclude training on your data, and Deepgram for voice). Do '
      'not share information you are not comfortable processing this way.';

  // ── Medical Disclaimer (full) ───────────────────────────────────────────────

  static const String medicalDisclaimer = '''
# Medical Disclaimer

**Last updated: 2026**

Clinix AI ("the App") is a personal health-information and organization tool. By using the App you acknowledge and agree to the following.

## Not medical advice
The App, including its AI health assistant, symptom guidance, and any summaries of your medical documents, provides **general health information for educational and organizational purposes only**. It is **not** professional medical advice, diagnosis, or treatment, and must not be relied upon as such.

## Not a medical device
The App is **not** a medical device. It does not diagnose, cure, treat, mitigate, or prevent any disease or condition, and is not intended to replace the clinical judgment of a licensed healthcare professional.

## AI limitations
AI-generated content can be inaccurate, incomplete, or out of date. Document analysis and summaries may misread or omit information. Always verify against your original records and your healthcare provider.

## Always consult a professional
Always seek the advice of a physician or other qualified health provider with any questions about a medical condition. Never disregard professional medical advice or delay seeking it because of something you read in the App.

## Emergencies
**If you think you may have a medical emergency, call your local emergency number or go to the nearest emergency department immediately.** Do not use the App in an emergency.

## No provider–patient relationship
Use of the App does not create a doctor–patient, provider–patient, or any professional relationship between you and Clinix AI or its developers.
''';

  // ── Insurance Disclaimer (full) ─────────────────────────────────────────────

  static const String insuranceDisclaimer = '''
# Insurance & Claims Disclaimer

**Last updated: 2026**

Clinix AI helps you organize insurance information and generate draft documents. By using these features you acknowledge and agree to the following.

## Not legal or financial advice
Information and AI-generated content relating to insurance — including claim reports, appeal letters, dispute letters, "fight your rejection" strategies, and references to regulators or ombudsman bodies — is **general information only**. It is **not** legal, financial, tax, or professional advice and is not a substitute for consulting a qualified attorney, licensed insurance adviser, or other professional.

## Review everything before you rely on it
AI-generated documents may contain factual, legal, or numerical errors. **You are solely responsible** for reviewing, correcting, and verifying any document before submitting it to an insurer, regulator, provider, or any third party. Clinix AI does not submit anything on your behalf and does not guarantee any outcome.

## No guarantee of outcome
We make no representation that any claim will be approved, that any appeal will succeed, or that any stated rights, deadlines, regulators, or escalation steps are current or applicable to your specific policy or jurisdiction.

## Jurisdiction
Insurance rules vary by country, region, and policy. Regional content is provided for general orientation only and may not reflect your situation.
''';

  // ── Terms of Use (full) ─────────────────────────────────────────────────────

  static const String termsOfUse = '''
# Terms of Use

**Last updated: 2026**

These Terms of Use ("Terms") govern your use of the Clinix AI application ("the App"). By creating an account or using the App, you agree to these Terms. If you do not agree, do not use the App.

## 1. Eligibility
You must be at least 18 years old (or the age of majority in your jurisdiction) to use the App. The App is intended for your own personal, non-commercial use.

## 2. Information and drafts, not advice or representation
The App helps you organise bills, insurance documents and health records, and uses AI to explain them, check bills for common errors against public reference prices, and draft letters (for example disputes, appeals and requests). Everything it produces is **general information and a draft for your review**. It is not medical, legal, financial, tax or insurance advice, and $companyName is not a law firm, licensed insurance adviser, medical-billing advocate, debt-settlement service or healthcare provider. **You decide what to send, you send it yourself, and you remain responsible for its accuracy.** We do not negotiate, appeal or act on your behalf and we do not guarantee that any bill will be reduced or any claim approved. See the Medical Disclaimer and Insurance Disclaimer, which are incorporated into these Terms.

## 3. Your responsibilities
You are responsible for the accuracy of information you enter, for safeguarding your account, and for reviewing any AI-generated content before relying on or sharing it. You agree not to misuse the App, attempt to extract credentials, or use it for any unlawful purpose.

## 4. Third-party services
The App uses third-party services including Google Firebase (authentication, database, storage, notifications, analytics, crash reporting), Google Gemini (AI processing, via our servers), Deepgram (voice transcription) and RevenueCat (subscription management). Your use is also subject to their terms. Content you submit for AI processing is transmitted to these providers.

## 4a. Subscriptions
Some features require a paid Clinix Pro subscription, billed through the Apple App Store or Google Play. Subscriptions renew automatically at the price shown at purchase until cancelled at least 24 hours before the end of the current period, in your App Store or Google Play account settings. Free allowances may change. Refunds are handled by the app store under its policies. Prices may vary by region and may change with notice.

## 4b. Fair use
AI features are metered to prevent abuse. Automated access, scraping, or use of the App to process documents for third parties commercially is not permitted without our written agreement.

## 5. Intellectual property
The App and its content (excluding your data) are owned by $companyName and protected by law. You retain ownership of the health data you provide.

## 6. Disclaimer of warranties
THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING FITNESS FOR A PARTICULAR PURPOSE AND ACCURACY.

## 7. Limitation of liability
TO THE MAXIMUM EXTENT PERMITTED BY LAW, $companyName AND ITS DEVELOPERS SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, OR CONSEQUENTIAL DAMAGES, OR ANY HARM ARISING FROM RELIANCE ON THE APP OR ITS AI-GENERATED CONTENT.

## 8. Account termination & deletion
You may delete your account and associated data at any time from within the App (Profile → Delete Account). We may suspend access for violation of these Terms.

## 9. Changes
We may update these Terms. Continued use after changes means you accept the updated Terms.

## 10. Contact
Questions: $contactEmail
''';

  // ── Privacy Policy (full) ───────────────────────────────────────────────────

  static const String privacyPolicy = '''
# Privacy Policy

**Last updated: 2026**

$companyName ("we", "us") respects your privacy. This policy explains what we collect, how we use it, and your rights. By using the App you consent to this policy.

## Information we collect
- **Account information:** your name and email from Sign in with Google or Apple; your country/region and the goals you select.
- **Consumer health and financial information you provide:** medical bills, insurance statements (EOBs), denial letters, policy documents, medical records, and the details extracted from them (providers, insurers, amounts, procedure codes, diagnoses); profile details (age, sex, blood group, allergies, conditions, emergency contact); symptoms, medications and reminders; the outcomes you record (amounts recovered).
- **Voice input** you choose to record.
- **Usage and diagnostic data:** feature usage events (for example that a scan or an audit was run — never the content), crash reports, and basic device information.
- **Purchase information:** subscription status from the app store via RevenueCat. We never see your card details.

## How we use it
- To provide the App's features: reading your documents, checking bills against public fair-price references, explaining denials, drafting letters, tracking deadlines, storing records, and reminders.
- To generate AI outputs at your request.
- To send notifications you enable.
- To keep the App reliable, prevent abuse (usage metering), and understand which features are used.

We do **not** sell your personal or health data, and we do not use your health data for advertising. We do not share it with insurers, providers, employers or data brokers.

## Consumer health data
Health information you provide is "consumer health data" under laws such as Washington's My Health My Data Act. We collect and use it only with your consent and only to provide the features you ask for. You may withdraw consent by deleting the relevant data or your account. We do not sell consumer health data and we do not use geofencing.

## Third-party processing
To provide AI features, the content you submit is sent through our own servers (Google Cloud) to:
- **Google Gemini** — text, image and PDF analysis. We use a paid tier whose terms state that your prompts and outputs are **not used to train or improve Google's models** and are not reviewed by humans for that purpose.
- **Deepgram** — voice-to-text transcription, if you use voice input.

Other processors: **Google Firebase** (authentication, encrypted database and file storage, push notifications, analytics, crash reporting) and **RevenueCat** (subscription status). These providers process data under their own privacy terms and data-processing agreements. Only share information you are comfortable processing this way.

## Storage, security & retention
Your data is stored in your private, access-controlled Firebase account space (Google Cloud, United States) and on your device. Documents you scan are kept locally on your device first, so they remain available offline. Data is encrypted in transit and at rest. AI requests are not stored by us beyond operational logs, which contain no document content. We retain your data until you delete it or your account. Server-side usage counters are deleted with your account.

## Security incidents
If a breach of unsecured identifiable health information occurs we will notify affected users (and regulators where required, including under the FTC Health Breach Notification Rule) without unreasonable delay.

## Your rights
You can view, edit and delete your data in the App and **delete your account and all associated data at any time** from Profile → Delete Account. Depending on where you live you may also have rights to access, correct, export, restrict or object to processing of your data, and to complain to a supervisory authority — including under the GDPR / UK GDPR (EU/EEA and UK), PIPEDA (Canada), the Privacy Act 1988 (Australia), the CCPA/CPRA and state consumer health data laws (United States) and the Digital Personal Data Protection Act 2023 (India). Contact us to exercise them; we respond within the time the applicable law requires (at most 45 days).

## International transfers
Our servers are in the United States. Where required, transfers from the EU/EEA, UK and other regions rely on standard contractual clauses or equivalent safeguards provided by our processors.

## Children
The App is not intended for children under 18 and we do not knowingly collect their data.

## Changes
We may update this policy and will reflect the new date above.

## Contact
$contactEmail
''';
}
