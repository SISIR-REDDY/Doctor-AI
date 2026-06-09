# App Store & Legal Compliance — Clinix AI

## Account type: you CAN ship on your individual (personal) account ✅

Apple forces an **Organization** account only when an app provides a *regulated
service* — e.g. it performs real diagnosis/triage as a medical device, dispenses
medication, IS an insurer/provider, or uses HealthKit **clinical health records**.

Clinix AI does **none** of these. It is a **personal organizer** for documents you
already have, plus an AI that gives **general information with disclaimers**. The
only iOS capabilities used are **Push Notifications** and **Sign in with Apple** —
both available on an individual account. There is **no HealthKit, no clinical
records entitlement**.

To keep it that way, the app's user-facing copy was repositioned away from
"medical service / diagnosis / fight your insurer / legal strategy" toward
"organize, prepare documents, general information." Keep this framing in your
**App Store Connect metadata** too (description, subtitle, keywords, screenshots).

**Recommended submission settings**
- **Category:** Health & Fitness (honest; allowed on individual accounts). Avoid
  the word "Medical" as the category.
- **Subtitle/description:** "Personal health & document organizer with an AI
  helper." Do NOT say "diagnose", "treatment", "medical device", "we fight
  insurers", or "legal advice".
- **Age rating:** expect a "Medical/Treatment Information" infrequent flag →
  rating ~12+/17+; that's normal, not a rejection.
- **Review notes:** "Informational and organizational tool for personal use. Not
  a medical device; does not diagnose or treat. AI provides general information
  with emergency redirection and disclaimers. Not an insurer and does not submit
  claims." Provide a demo account.

---


This document tracks the compliance work done in-app and the steps **you** must
complete outside the code before submitting to the App Store. Health + insurance
apps get extra scrutiny under App Review Guidelines **1.4.1 (physical harm)** and
**5.1.1 (privacy / data / account)**.

## ✅ Done in the app

| Risk | Fix | Where |
|------|-----|-------|
| No account deletion (auto-reject, 5.1.1(v)) | "Delete Account" in Profile → wipes all Firestore data + deletes auth user (re-auths if needed) | `AuthService.deleteAccount`, `FirestoreService.deleteAllUserData`, Profile screen |
| No privacy policy / terms | Full in-app Privacy Policy, Terms, Medical & Insurance disclaimers + URL slots | `core/config/legal_content.dart`, `features/legal/` |
| No consent / disclaimer gate | First-run blocking consent screen (checkbox required) + legal links on sign-in | `features/legal/consent_gate_screen.dart`, `ConsentService`, `auth_gate_screen.dart` |
| AI gives unsafe medical advice | System prompt now forces emergency/self-harm redirection, no diagnosis, no doses; persistent in-chat disclaimer | `features/ai_chat/ai_health_assistant_screen.dart` |
| Insurance = unlicensed legal advice | Insurance disclaimer (consent + Legal hub) + "not legal advice, review before submitting" footer on every generated PDF | `legal_content.dart`, `claim_pdf_service.dart` |
| Third-party health-data processing undisclosed | Privacy policy + consent screen disclose Gemini, Deepgram, Firebase | `legal_content.dart`, consent gate |

## ⚠️ You MUST do before submitting

1. **Have a lawyer review** `legal_content.dart`. The text is a thorough starting
   point, not legal advice. Set your real company name / contact email there.
2. **App Store Connect → App Privacy:** declare every data type collected (health,
   contact info, identifiers, audio, diagnostics) and that data is sent to
   third parties (Google, Deepgram). This "nutrition label" must match the app.
3. **Privacy Policy URL** is a required field in App Store Connect. Host the
   policy and put the URL in `AppLegal.privacyPolicyUrl` (and App Store Connect).
4. **App Review notes:** state that the app is an informational/organizational
   tool, NOT a medical device, and explain the AI is general guidance with
   emergency redirection. Provide a demo account.
5. **🔴 API key exposure (security/billing risk):** `app_runtime/api_keys` is
   readable by any signed-in user, so your Gemini + Deepgram keys can be
   extracted. Firestore rules cannot hide a value the client reads. **Before
   public launch, proxy these calls through a backend (Cloud Function / Cloud
   Run) that holds the keys server-side**, then set the rule to `allow read: if
   false`. See the comment in `firestore.rules`. Also rotate any keys that have
   shipped in a build.
6. **Secrets in repo:** `firebase_options.dart`, `google-services.json`,
   `GoogleService-Info.plist` are committed. Firebase client config is not secret
   *if* Firestore/Storage rules are locked down (they are, for user data) — but
   the Gemini/Deepgram keys behind item 5 are the real exposure.
7. **Deploy the Firestore rules** in `firestore.rules` (and `storage.rules`) to
   your Firebase project — verify in the console they are published.
8. Confirm **Sign in with Apple** is offered (it is) since you also offer Google —
   required by 4.8 when using a third-party login.

## Notes
- Consent acceptance is versioned (`AppLegal.consentVersion`). Bump it when terms
  change materially to re-prompt all users.
- The in-chat and PDF disclaimers are intentionally always visible, not one-time.
