# Clinix backend (Cloud Functions)

Server-side AI proxy, usage metering, entitlements and fair-price benchmarks.
The app never holds an AI key.

## One-time setup

```bash
# 1. Blaze plan is required for Cloud Functions + outbound calls (console → Upgrade).
# 2. Log in and pick the project
firebase login
firebase use clinixai-9bb6d

# 3. Secrets (never commit these)
#    Use a key from a Google Cloud project WITH BILLING ENABLED so prompts are
#    on the PAID tier: paid-tier data is NOT used to train models and is not
#    human-reviewed. Free-tier keys are not acceptable for health documents.
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET   # any long random string

# 4. Deploy rules + functions
firebase deploy --only firestore:rules,storage,functions
```

## After the first successful deploy

1. In `firestore.rules` set `legacyKeysReadable()` to `false`, redeploy rules, and
   delete the `app_runtime/api_keys` document. Rotate the old Gemini key.
2. Create `app_runtime/config` (optional overrides):
   ```json
   { "everyonePro": true, "enforceAppCheck": false,
     "models": { "fast": ["gemini-2.5-flash"], "smart": ["gemini-2.5-pro","gemini-2.5-flash"] } }
   ```
   `everyonePro: true` = free beta (pair with Remote Config `everyone_pro = true`).
3. Enable **App Check** in the console (Play Integrity + App Attest), register debug
   tokens for your dev devices, then set `enforceAppCheck: true`.
4. **RevenueCat**: create the `pro` entitlement, products `clinix_pro_monthly` /
   `clinix_pro_yearly`, an offering with both packages; add the webhook
   (URL of `revenuecatWebhook`, Authorization = the secret above); pass the public
   SDK keys with `--dart-define=RC_ANDROID_KEY=… --dart-define=RC_IOS_KEY=…` or
   Remote Config `rc_android_key` / `rc_ios_key`.

## Benchmarks (US fair prices)

```bash
cd functions && npm run build
npm run seed:benchmarks            # approximate seed for ~130 common codes
# Exact figures from the official CMS files (download from cms.gov):
npm run import:cms -- --type pfs  --file PPRRVU26_JAN.csv --cf 33.40 --year 2026
npm run import:cms -- --type clfs --file CLFS26.csv --year 2026
```

## Local emulation

```bash
cd functions && npm run serve
```
Set `FirebaseConfig.useEmulator = true` in the app to point Auth/Firestore at the
emulators (add `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)`).

## Endpoints (callable)

| Name | Quota op | Purpose |
|---|---|---|
| `analyzeDocument` | analyze | classify + extract bill / EOB / denial / policy / record |
| `auditBills` | audit | deterministic rules + benchmarks + AI audit |
| `draftLetter` | letter | appeal, dispute, itemized request, charity care, medical necessity, regulator/ombudsman complaint, records request |
| `explainDenial` | explain | plain-language denial analysis + appeal plan |
| `chat` | chat | grounded coverage chat / general-health chat |
| `generate` | generate | transitional passthrough for legacy prompts |
| `revenuecatWebhook` | — | HTTPS webhook → `users/{uid}/private/entitlement` |

Quotas per plan live in `functions/src/config.ts` (`DEFAULT_CONFIG.limits`) and can be
overridden in `app_runtime/config.limits`.
