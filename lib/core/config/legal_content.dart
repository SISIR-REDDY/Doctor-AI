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
  static const int consentVersion = 1;

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
      'To answer your questions and analyze documents, Clinix AI sends your input '
      '(including text, voice, and document images you choose to share) to '
      'third-party AI providers (Google Gemini and Deepgram). Do not share '
      'information you are not comfortable processing this way.';

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

## 2. Health information, not advice
The App provides general health and insurance information and organization tools. It does not provide medical, legal, or financial advice. See the in-app Medical Disclaimer and Insurance Disclaimer, which are incorporated into these Terms.

## 3. Your responsibilities
You are responsible for the accuracy of information you enter, for safeguarding your account, and for reviewing any AI-generated content before relying on or sharing it. You agree not to misuse the App, attempt to extract credentials, or use it for any unlawful purpose.

## 4. Third-party services
The App uses third-party services including Google Firebase (authentication, database, storage, notifications), Google Gemini, and Deepgram. Your use is also subject to their terms. Content you submit for AI processing is transmitted to these providers.

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
- **Account information:** your name and email from Sign in with Google or Apple.
- **Health information you provide:** profile details (age, sex, blood group, allergies, conditions, emergency contact), symptoms, medications, reminders, insurance policies and claims, and medical documents/images you scan or upload.
- **Voice input** you record to describe symptoms.
- **Technical/diagnostic data:** crash reports and basic device information to keep the App stable.

## How we use it
- To provide the App's features (records vault, reminders, AI assistance, insurance tools).
- To generate AI summaries, reports, and letters at your request.
- To send you notifications you enable (e.g. medication reminders).
- To diagnose crashes and improve reliability.

We do **not** sell your personal or health data.

## Third-party processing
To provide AI features, content you submit is sent to:
- **Google Gemini** — text and document/image analysis.
- **Deepgram** — voice-to-text transcription.
- **Google Firebase** — authentication, encrypted database/storage, push notifications, and crash reporting.

These providers process data under their own privacy terms. Only share information you are comfortable processing this way.

## Storage & security
Your data is stored in your private, access-controlled Firebase account space and on your device. Documents you scan are also kept locally on your device so they remain available offline. We use reasonable technical measures to protect your data, but no system is perfectly secure.

## Your rights
You can view and edit your data in the App. You can **delete your account and associated data at any time** from Profile → Delete Account. Depending on your region (e.g. GDPR/CCPA), you may have rights to access, correct, export, or erase your data; contact us to exercise them.

## Children
The App is not intended for children under 18 and we do not knowingly collect their data.

## Changes
We may update this policy and will reflect the new date above.

## Contact
$contactEmail
''';
}
