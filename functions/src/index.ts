/**
 * Clinix AI backend.
 *
 * Every AI call the app makes goes through these callables so the Gemini key
 * never ships in the client, prompts are versioned server-side, and usage is
 * metered per user and plan. Deploy with `firebase deploy --only functions`
 * after `firebase functions:secrets:set GEMINI_API_KEY`.
 */
import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { logger, setGlobalOptions } from 'firebase-functions/v2';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall, onRequest, type CallableRequest } from 'firebase-functions/v2/https';
import { timingSafeEqual } from 'node:crypto';
import { ZodError, z } from 'zod';
import * as functionsV1 from 'firebase-functions/v1';

import { authorize, consumeQuota, refundQuota } from './quota';
import type { QuotaOp } from './config';
import { analyzeDocument as runAnalyze, analyzeInput } from './tasks/analyze';
import { auditBills as runAudit, auditInput } from './tasks/audit';
import { draftLetter as runLetter, explainDenial as runExplain, explainInput, letterInput } from './tasks/letters';
import { chat as runChat, chatInput, generateInput, legacyGenerate } from './tasks/chat';

initializeApp();
setGlobalOptions({ region: 'us-central1', maxInstances: 20 });

const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
const REVENUECAT_WEBHOOK_SECRET = defineSecret('REVENUECAT_WEBHOOK_SECRET');

function parse<S extends z.ZodTypeAny>(schema: S, data: unknown): z.output<S> {
  try {
    return schema.parse(data ?? {});
  } catch (err) {
    if (err instanceof ZodError) {
      const issue = err.issues[0];
      throw new HttpsError('invalid-argument', `Invalid request: ${issue?.path.join('.') || 'input'} — ${issue?.message}`);
    }
    throw err;
  }
}

/** Shared wrapper: auth → quota → task, with structured logging. */
async function runTask<S extends z.ZodTypeAny, TOut>(
  req: CallableRequest<unknown>,
  op: QuotaOp,
  schema: S,
  task: (uid: string, apiKey: string, input: z.output<S>) => Promise<TOut>,
): Promise<TOut & { plan: string }> {
  const ctx = await authorize(req);
  const input = parse(schema, req.data);
  await consumeQuota(ctx, op);
  const started = Date.now();
  try {
    const out = await task(ctx.uid, GEMINI_API_KEY.value(), input);
    logger.info('task.ok', { op, uid: ctx.uid, plan: ctx.plan, ms: Date.now() - started });
    return { ...out, plan: ctx.plan };
  } catch (err) {
    logger.error('task.fail', { op, uid: ctx.uid, ms: Date.now() - started, err: String((err as Error)?.message ?? err) });
    // The user pays a quota unit for a result, not for our outage. Refund
    // unless the failure was theirs (bad input) — provider errors included.
    const code = err instanceof HttpsError ? err.code : 'internal';
    if (code !== 'invalid-argument' && code !== 'permission-denied') {
      await refundQuota(ctx, op);
    }
    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', 'Something went wrong while processing. Please try again.');
  }
}

// 1 GiB / 240 s per instance. Concurrency is capped because each request can
// hold up to ~20 MB of base64 pages in memory; 80 (the v2 default) would let
// one instance run out. 20 instances × 12 = 240 in-flight AI calls, enough for
// tens of thousands of daily actives; raise maxInstances in setGlobalOptions
// before a marketing push.
const aiOpts = { secrets: [GEMINI_API_KEY], memory: '1GiB' as const, cpu: 1, concurrency: 12, timeoutSeconds: 240, cors: true };

/** Classify + extract structured data from bill / EOB / denial / policy / record images or PDFs. */
export const analyzeDocument = onCall(aiOpts, (req) => runTask(req, 'analyze', analyzeInput, runAnalyze));

/** Deterministic rules + benchmarks + AI audit of a case's bills. */
export const auditBills = onCall(aiOpts, (req) => runTask(req, 'audit', auditInput, (_uid, key, input) => runAudit(key, input)));

/** Draft appeal / dispute / itemized-request / charity-care / … letters. */
export const draftLetter = onCall(aiOpts, (req) => runTask(req, 'letter', letterInput, (_uid, key, input) => runLetter(key, input)));

/** Explain a denial and assess the appeal. */
export const explainDenial = onCall(aiOpts, (req) => runTask(req, 'explain', explainInput, (_uid, key, input) => runExplain(key, input)));

/** Grounded coverage chat or general-health chat. */
export const chat = onCall(aiOpts, (req) => runTask(req, 'chat', chatInput, (_uid, key, input) => runChat(key, input)));

/** Transitional passthrough for legacy client-built prompts. */
export const generate = onCall(aiOpts, (req) => runTask(req, 'generate', generateInput, (_uid, key, input) => legacyGenerate(key, input)));

/**
 * RevenueCat → Firestore entitlement sync.
 * Configure in RevenueCat: Integrations → Webhooks → URL of this function,
 * Authorization header = the REVENUECAT_WEBHOOK_SECRET value.
 * The app calls Purchases.logIn(firebaseUid) so app_user_id == uid.
 */
export const revenuecatWebhook = onRequest({ secrets: [REVENUECAT_WEBHOOK_SECRET], cors: false }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }
  const auth = req.get('Authorization') ?? '';
  const expected = REVENUECAT_WEBHOOK_SECRET.value();
  if (!expected || !(safeEqual(auth, expected) || safeEqual(auth, `Bearer ${expected}`))) {
    res.status(401).send('Unauthorized');
    return;
  }
  const event = (req.body?.event ?? {}) as {
    type?: string;
    app_user_id?: string;
    original_app_user_id?: string;
    entitlement_ids?: string[];
    expiration_at_ms?: number;
    product_id?: string;
    store?: string;
    environment?: string;
    event_timestamp_ms?: number;
  };
  const uid = [event.app_user_id, event.original_app_user_id].find((id) => id && !id.startsWith('$RCAnonymousID:'));
  if (!uid) {
    res.status(200).send('ignored (anonymous)');
    return;
  }
  const hasPro = (event.entitlement_ids ?? []).includes('pro');
  const expiresMs = event.expiration_at_ms ?? 0;
  const active = hasPro && (expiresMs === 0 || expiresMs > Date.now()) && event.type !== 'EXPIRATION';
  const eventAt = event.event_timestamp_ms ?? Date.now();
  const ref = getFirestore().doc(`users/${uid}/private/entitlement`);
  // Webhooks retry and can arrive out of order; an older RENEWAL must not
  // overwrite a newer EXPIRATION. Compare event timestamps inside the write.
  const applied = await getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const prevAt = (snap.data()?.lastEventAt as number | undefined) ?? 0;
    if (eventAt < prevAt) return false;
    tx.set(
      ref,
      {
        plan: active ? 'pro' : 'free',
        expiresAt: expiresMs ? Timestamp.fromMillis(expiresMs) : null,
        source: `revenuecat:${event.store ?? 'unknown'}:${event.environment ?? ''}`,
        productId: event.product_id ?? '',
        lastEvent: event.type ?? '',
        lastEventAt: eventAt,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return true;
  });
  logger.info('revenuecat.synced', { uid, type: event.type, active, applied });
  res.status(200).send(applied ? 'ok' : 'stale (ignored)');
});

function safeEqual(a: string, b: string): boolean {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

/**
 * Account deletion clean-up: the client deletes what the rules let it touch;
 * this trigger removes the whole `users/{uid}` tree (including server-only
 * `private/*` docs) and the user's Storage files once the auth user is gone.
 */
export const onUserDeleted = functionsV1.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  try {
    await getFirestore().recursiveDelete(getFirestore().doc(`users/${uid}`));
  } catch (err) {
    logger.error('user_delete.firestore_failed', { uid, err: String(err) });
  }
  try {
    const { getStorage } = await import('firebase-admin/storage');
    const bucket = getStorage().bucket();
    await bucket.deleteFiles({ prefix: `document_scans/${uid}/` });
    await bucket.deleteFiles({ prefix: `uploads/${uid}/` });
  } catch (err) {
    logger.error('user_delete.storage_failed', { uid, err: String(err) });
  }
  logger.info('user_delete.done', { uid });
});
