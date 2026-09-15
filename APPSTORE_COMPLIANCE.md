# Clinix — launch & compliance checklist

Clinix is positioned as a **personal health copilot** with the bill-and-insurance
advocate as its hero: it reads bills, insurer statements (EOBs), denial letters,
policies and medical reports; audits bills against public fair-price references;
explains denials and lab results in plain language; drafts letters the **user
reviews and sends themselves**; keeps records, medications and reminders in one
vault; and offers an AI health assistant grounded on the user's own documents. It does **not**
diagnose, treat, represent, negotiate, appeal or submit anything on the user's
behalf. Keep that framing everywhere (app copy, store listing, review notes) —
it is what keeps the app out of medical-device, legal-services and
debt-settlement regulation, and lets it ship from an individual developer
account under **Health & Fitness** (or **Finance**).

## 1. Backend (must be live before any public build)

| Step | Where | Why |
|---|---|---|
| Blaze plan, `firebase use clinixai-9bb6d` | Firebase console / CLI | Cloud Functions + outbound API calls |
| `firebase functions:secrets:set GEMINI_API_KEY` — key from a project **with billing enabled** | CLI | Paid tier: prompts are not used for training and not human-reviewed. A free-tier key is a privacy violation for health documents. |
| `firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET` | CLI | Authenticates subscription webhooks |
| `firebase deploy --only firestore:rules,storage,functions` | CLI | Rules lock `benchmarks/`, `app_runtime/config`, `users/*/private/*`; functions hold the AI keys |
| After deploy: set `legacyKeysReadable()` → `false` in `firestore.rules`, redeploy, delete `app_runtime/api_keys`, **rotate** the old Gemini/Deepgram keys | Console + CLI | Old builds could read those keys |
| `cd functions && npm run seed:benchmarks`, then `npm run import:cms` with the current CMS PFS/CLFS files | CLI | Exact Medicare reference prices instead of the approximate seed |
| Create `app_runtime/config` (`everyonePro: true` for beta; `enforceAppCheck: true` once App Check is registered) | Firestore console | Beta switch / abuse protection |
| Enable App Check (Play Integrity + App Attest); register debug tokens for dev devices | Firebase console | Blocks scripted abuse of the AI endpoints |
| Enable Crashlytics, Analytics, Remote Config params (`min_build_number`, `everyone_pro`, `rc_android_key`, `rc_ios_key`, prices) | Firebase console | Already wired in the app |

## 2. Subscriptions (RevenueCat)

1. Products in App Store Connect / Play Console: `clinix_pro_monthly`, `clinix_pro_yearly`.
2. RevenueCat: entitlement `pro`, offering `default` with the two packages, webhook →
   `revenuecatWebhook` function URL, Authorization header = the secret above.
3. Public SDK keys via `--dart-define=RC_ANDROID_KEY=… --dart-define=RC_IOS_KEY=…` or
   Remote Config `rc_android_key` / `rc_ios_key`.
4. Both stores require IAP for digital subscriptions — never link to external payment.
5. Free allowances (per month): 6 document reads, 1 audit, 1 letter, 2 denial analyses,
   20 chats — see `functions/src/config.ts`. Adjust in `app_runtime/config.limits`.

## 3. Legal (have counsel review before launch)

- `lib/core/config/legal_content.dart` — Terms (drafts-not-advice, no representation,
  subscriptions, fair use), Privacy Policy (consumer health data, paid-tier AI
  processing, retention, breach notification, regional rights, transfers), Medical
  and Insurance disclaimers. **Set the real company name and a non-Gmail contact.**
- Consent is captured on the sign-in step (checkbox gates the buttons); bump
  `AppLegal.consentVersion` when terms change materially.
- **Do not charge contingency / success fees yourself** until counsel has reviewed
  state debt-settlement / credit-services laws (medical bills are consumer debt) and
  any patient-advocate rules — subscription + per-case pricing is clean.
- Letters are drafts; the app never sends anything itself. Keep it that way unless
  counsel signs off on fax/mail integrations.
- Regional: GDPR/UK GDPR (health = special category — keep the explicit consent,
  DPIA on file, EU representative when serving EU users at scale), PIPEDA, Australian
  Privacy Act, CCPA/CPRA + Washington MHMDA / Nevada / Connecticut consumer-health
  laws (separate consumer-health-data policy section is in the privacy policy),
  India DPDP 2023 (when launching there).
- FTC Health Breach Notification Rule applies (non-HIPAA health app): keep a breach
  response procedure; notify users/FTC within the statutory windows.
- Google Gemini paid-tier data terms and Firebase DPA cover processor obligations;
  add RevenueCat's and Deepgram's DPAs to your records.

## 4. App Store Connect / Google Play

- **Category:** Health & Fitness or Finance. Avoid "Medical".
- **Privacy nutrition label / Data safety:** health & financial documents, identifiers,
  contact info, usage data, diagnostics, purchases; shared with processors (Google,
  Deepgram, RevenueCat); not used for advertising/tracking; deletable in-app.
- **Google Play Health apps declaration:** yes — health & fitness / medical information;
  no HealthKit/Health Connect access.
- **Review notes:** "Personal organisation and information tool for medical bills and
  insurance documents. Not a medical device; does not diagnose. AI outputs are
  general information and drafts the user reviews and sends themselves. Not an
  insurer, advocate or law firm. Subscriptions via IAP." Provide a demo account with
  sample documents already scanned and `everyonePro` on for the reviewer.
- Account deletion: Profile → Delete Account (client) + `onUserDeleted` function
  (server wipe incl. Storage). ✅
- Sign in with Apple offered alongside Google. ✅
- iOS usage strings for camera / photo library / microphone / Face ID present. ✅
- Push/notification permission requested contextually (deadlines, medications). ✅
- Accessibility: dynamic type works; audit VoiceOver labels on icon-only buttons before submission.

## 5. Statistics used in marketing copy (keep sourced)

Every number in the onboarding and store listing must trace to one of these.
Re-verify annually; drop a claim rather than keep a stale one.

| Claim | Source |
|---|---|
| ~8 in 10 medical bills contain an error | Widely cited industry estimate (Medical Billing Advocates of America); phrase as "up to" in store copy |
| Under 1% of in-network denials are appealed; ~44% of appeals succeed | KFF analysis of ACA marketplace insurer transparency data |
| Lab results reach patients instantly, often before the clinician | 21st Century Cures Act information-blocking rule (2021); JAMIA Open 2025 on portal comprehension |
| Doctor-messaging apps charge ~\$49/month | K Health published pricing (2026) — cite as "some apps charge", not a named competitor, in store copy |
| 125,000 deaths and \$300B avoidable cost per year from medication non-adherence | Long-standing US estimates (Annals of Internal Medicine 2012; restated in 2025 industry reviews) |

## 6. Positioning guardrails (do not regress)

- No "diagnose", "treatment", "medical device", "we fight insurers", "we negotiate",
  "guaranteed savings", "legal advice" anywhere in copy or screenshots.
- Savings are always "potential" / "estimated"; benchmarks are labelled approximate
  until the CMS import runs.
- Emergency redirection and "not medical advice" remain in the health chat prompt
  (server-side, `functions/src/ai/prompts.ts`).

## 7. Before scaling

- Rate limits are per user; add a per-IP layer (Cloud Armor / App Check enforcement)
  before marketing pushes.
- Consider Vertex AI with a regional endpoint (EU) for EU/UK data-residency asks.
- Add a status page / support email (not Gmail) in Profile → Legal.
