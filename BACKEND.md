# Clinix backend — how data moves, how it is protected, how it scales

Read this before deploying or answering a security questionnaire. Every claim
here points at code; if the code changes, change this.

## 1. What happens to a document

```
phone                              Cloud Functions (us-central1)            Google
─────                              ─────────────────────────────            ──────
photo/PDF ──► base64 (≤9 MB) ──►  analyzeDocument                            
   or Storage path ─────────────►    authorize()  auth + App Check           
                                     consumeQuota() Firestore txn            
                                     classify (flash, JSON schema) ────────► Gemini
                                     extract  (flash, JSON schema) ────────► Gemini
              structured JSON ◄──    (line items / markers / denial …)
saved to Firestore users/{uid}/…  ◄─ client writes what it chooses to keep
```

* **The AI key never leaves the server.** It is a Functions secret
  (`GEMINI_API_KEY`), read at call time. The client cannot call Gemini.
* **Every call is authenticated** (`request.auth.uid` required — no anonymous
  sign-in exists in the app) and, once `enforceAppCheck` is on, **attested**
  (Play Integrity / App Attest) so scripts cannot impersonate the app.
* **Quota is consumed in a Firestore transaction** before the AI runs, and
  refunded if *our* side fails (provider outage, internal error). Limits per
  plan live in `app_runtime/config` and can change without a release.
* **Inputs are validated with zod** — MIME allow-list (JPEG/PNG/WebP/HEIC/PDF),
  ≤12 files, ≤9 MB inline / ≤20 MB via Storage, text fields capped. A Storage
  path is only read if it is under the caller's own prefix.
* **Outputs are schema-forced JSON** (`responseSchema`), so the app never
  parses prose; a malformed reply falls through the model chain and then
  fails cleanly with a refund.
* **Prompt injection**: the system prompt instructs the model to treat document
  text as data and ignore instructions inside it; user hints are bounded and
  labelled as hints.

## 2. Where data lives, and who can read it

| Data | Location | Readable by | Written by |
|---|---|---|---|
| Scanned images / PDFs | Storage `document_scans/{uid}/…` | owner only | owner (type + 25 MB rules) |
| Extracted bills, cases, letters, deadlines | Firestore `users/{uid}/{collection}` | owner only | owner |
| Lab markers, records, medications, logs | Firestore `users/{uid}/…` | owner only | owner |
| Chat history | Firestore `users/{uid}/ai_chats` | owner only | owner |
| Plan / entitlement | `users/{uid}/private/entitlement` | owner (read) | **RevenueCat webhook only** |
| Usage counters | `users/{uid}/private/usage` | owner (read) | **Functions only** |
| Runtime config, models, limits | `app_runtime/config` | nobody (client) | console / admin |
| Fair-price benchmarks (CMS) | `benchmarks/…` | nobody (client) | seed / import scripts |

Rules of note (`firestore.rules`, `storage.rules`):

* A client **cannot grant itself Pro**: `plan` / `entitlement` / `isPro` keys
  are rejected on the user doc, and `private/*` is write-closed.
* Nothing is shared between users; there are no cross-user reads anywhere.
* `app_runtime/api_keys` is still readable by signed-in users via
  `legacyKeysReadable()` — **this is the one open item**. Flip it to `false`,
  delete the document and rotate the old keys as soon as the functions are
  deployed (see §6).

## 3. What Google sees, and for how long

* Gemini is called on the **paid tier**. Under Google's paid-tier terms prompts
  and files are **not used to train models and are not human-reviewed**. A
  free-tier key would break that promise — never use one for health data.
* Requests are processed and discarded; Clinix does not enable any provider
  caching of content.
* Function logs record **operation, uid, plan, model, latency, token counts
  and error codes — never document content or model output**
  (`gemini.badjson` logs length only). Token counts per call (`gemini.ok`)
  are what to chart for model spend per plan. Crashlytics/Analytics likewise carry event names, not content.

## 4. Retention and deletion

* Data stays until the user deletes it. In-app delete removes the Firestore
  doc and its Storage files.
* **Account deletion** (Profile → Delete account) removes the Auth user; the
  `onUserDeleted` trigger then recursively deletes `users/{uid}` — including
  `private/*` the client could never touch — and both Storage prefixes.
  App Store 5.1.1(v) satisfied.
* Recommended before scale (not yet configured): Firestore TTL policy on
  `users/*/ai_chats` (e.g. 180 days) — chat is the one collection that grows
  without the user curating it. Set via console → TTL on an `expiresAt` field.

## 5. Scale, cost, abuse

**Capacity.** Each AI function runs at 1 GiB / 1 vCPU / 240 s with
`concurrency: 12` and `maxInstances: 20` → 240 simultaneous AI calls. A scan
takes 4–12 s; that is on the order of **50–70 k scans/hour** of headroom,
far beyond early traction. Raise `maxInstances` in `setGlobalOptions` before a
campaign; there is no other bottleneck — Firestore is per-user documents
with no composite queries (no index build needed).

**Cold starts.** ~2–4 s on the first call after idle. Set `minInstances: 1` on
`analyzeDocument` once there is daily traffic; it costs roughly $10–15/month.

**Cost per user.** One scan ≈ 2 flash calls; an audit ≈ 1 flash call + rules;
a letter ≈ 1 call. A heavy Pro user is well under **$0.50/month** in model
spend at current list prices. Quotas cap the worst case per user; the daily
cap (60 free / 250 pro) caps runaway loops.

**Abuse.** Auth-only (no anonymous accounts) + App Check + per-user daily caps
+ payload limits. The remaining vector is many real Google/Apple accounts —
App Check plus the free-tier caps make that uneconomic. Add a Cloud Armor /
per-IP rule at the load-balancer level only if it ever shows up in logs.

**Regions.** Everything is `us-central1`. EU/UK users are served from the US,
which is acceptable under standard contractual clauses for a processor, but
for data-residency asks (employers, NHS-adjacent) deploy a second codebase in
`europe-west2` and route by the profile's country. Vertex AI regional endpoints
make the model call residency-clean too.

## 6. Deploy checklist (in order)

1. Blaze plan · `firebase use <project>`.
2. `firebase functions:secrets:set GEMINI_API_KEY` (paid-tier key) and
   `REVENUECAT_WEBHOOK_SECRET`.
3. `cd functions && npm test && npm run build`.
4. `firebase deploy --only firestore:rules,storage,functions`.
5. Create `app_runtime/config` with `{ everyonePro: true }` for beta.
6. `npm run seed:benchmarks`, then `npm run import:cms` with current CMS files.
7. Ship the build that uses the callables; confirm in logs.
8. **Then**: `legacyKeysReadable()` → `false`, redeploy rules, delete
   `app_runtime/api_keys`, **rotate the old Gemini and Deepgram keys**.
9. Register App Check (Play Integrity + App Attest), debug tokens for dev
   devices, then set `enforceAppCheck: true` in `app_runtime/config`.
10. RevenueCat: products, entitlement `pro`, webhook URL + secret.

## 7. Verified by tests

`functions/test/audit_rules.test.ts` (`npm test`): the four deterministic
audit rules including their negative cases — a 2.9× charge is not
"overpriced", the same code on different dates is not a "duplicate", a
multi-unit line is not a duplicate, ≤2 % rounding is not a "math error" —
plus code normalisation, JSON recovery and region fallback. These are the
rules that turn a scan into a dollar claim; they must never accuse on a
coincidence.

## 8. Still to build

* Firestore TTL on chat history (§4).
* `minBuild` is read from config but not enforced — callables carry no build
  number. Add `appBuild` to every callable payload and reject below it, or
  keep relying on the Remote Config force-update gate the app already has.
* EU region deployment when a customer requires it (§5).
