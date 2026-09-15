# Clinix — your health, understood and defended

Scan any medical bill, insurer statement (EOB), denial letter or lab report. Clinix
reads it, checks bills against fair-price references, explains denials and results in
plain English, drafts the dispute or appeal for you to send, tracks deadlines, and
records the money you get back. Records, medications, reminders and an AI health
assistant grounded on your own documents live alongside — for you and your family.

**Markets:** US, UK, Canada, Australia, EU first; India next (region engine in
`lib/core/config/insurance_regions.dart` + `functions/src/regions.ts`).

## Architecture

```
Flutter app (lib/)
├─ features/onboarding   welcome slides → consent + sign-in → country/goals → first scan
├─ features/home         shell (glass tab bar) + money dashboard
├─ features/scan         universal scanner → backend extraction → review → save
├─ features/claims       cases: bills, audit findings, denial plan, letters, deadlines
├─ features/letters      edit / PDF / share / mark sent
├─ features/deadlines    cross-case deadlines with local reminders
├─ features/insurance    policies + deductible / OOP tracker (from EOBs)
├─ features/records      medical records vault
├─ features/care         medications, reminders, symptom journal, health details
├─ features/paywall      Clinix Pro (RevenueCat)
├─ services/ai           AiService (Cloud Functions callables), chat context builder
├─ services/advocate     AdvocateService — audit / explain / deadlines / letters / outcomes
└─ models                patient_models.dart (+ advocate_models.dart)

Cloud Functions (functions/) — TypeScript, Node 22
├─ analyzeDocument · auditBills · draftLetter · explainDenial · chat · generate
├─ server-side prompts + JSON schemas, per-plan quotas, model fallback
├─ benchmarks: CMS Medicare seed + importer (fair-price references)
├─ revenuecatWebhook → users/{uid}/private/entitlement
└─ onUserDeleted → recursive data + storage wipe
```

The app never holds an AI key. See `functions/README.md` for deployment and
`APPSTORE_COMPLIANCE.md` for the launch/legal checklist.

## Run

```bash
flutter pub get
flutter run   # debug builds are treated as Pro locally; the backend still meters usage
```

Optional build-time config:

```
--dart-define=RC_ANDROID_KEY=goog_…   --dart-define=RC_IOS_KEY=appl_…
--dart-define=GEMINI_API_KEY=…         # dev-only fallback while functions are not deployed
```

## Test

```bash
flutter analyze
flutter test
cd functions && npm run build
```
