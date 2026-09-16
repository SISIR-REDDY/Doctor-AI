import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { getRuntimeConfig, type Plan, type QuotaOp } from './config';

/**
 * Entitlements live at users/{uid}/private/entitlement and are written ONLY
 * by the RevenueCat webhook / admin. Usage counters live next to them at
 * users/{uid}/private/usage. Firestore rules make `private/*` read-only for
 * the owner, so a client can never grant itself Pro or reset its quota.
 */
export interface Entitlement {
  plan: Plan;
  expiresAt?: Timestamp | null;
  source?: string;
}

export interface AuthedContext {
  uid: string;
  plan: Plan;
}

/** Validates auth (+ App Check when enforced) and resolves the caller's plan. */
export async function authorize(req: CallableRequest<unknown>): Promise<AuthedContext> {
  const cfg = await getRuntimeConfig();
  if (!req.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Sign in to use Clinix AI features.');
  }
  if (cfg.enforceAppCheck && !req.app) {
    throw new HttpsError('failed-precondition', 'This request could not be verified. Update the app and try again.');
  }
  const plan = await resolvePlan(req.auth.uid, cfg.everyonePro);
  return { uid: req.auth.uid, plan };
}

export async function resolvePlan(uid: string, everyonePro: boolean): Promise<Plan> {
  if (everyonePro) return 'pro';
  try {
    const snap = await getFirestore().doc(`users/${uid}/private/entitlement`).get();
    if (!snap.exists) return 'free';
    const ent = snap.data() as Entitlement;
    if (ent.plan !== 'pro') return 'free';
    if (ent.expiresAt && ent.expiresAt.toMillis() < Date.now()) return 'free';
    return 'pro';
  } catch (err) {
    logger.warn('entitlement.read_failed', { uid, err: String(err) });
    return 'free';
  }
}

/**
 * Atomically consumes one unit of `op` for the user or throws
 * `resource-exhausted` with details the app uses to open the paywall.
 */
export async function consumeQuota(ctx: AuthedContext, op: QuotaOp): Promise<void> {
  const cfg = await getRuntimeConfig();
  const limits = cfg.limits[ctx.plan];
  const now = new Date();
  const month = now.toISOString().slice(0, 7); // YYYY-MM
  const day = now.toISOString().slice(0, 10); // YYYY-MM-DD
  const ref = getFirestore().doc(`users/${ctx.uid}/private/usage`);

  await getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = (snap.data() ?? {}) as {
      month?: string;
      day?: string;
      counts?: Partial<Record<QuotaOp, number>>;
      dayCount?: number;
    };
    const counts = data.month === month ? { ...(data.counts ?? {}) } : {};
    const dayCount = data.day === day ? data.dayCount ?? 0 : 0;
    const used = counts[op] ?? 0;

    if (dayCount >= limits.dailyCap) {
      throw new HttpsError('resource-exhausted', 'Daily limit reached. Please try again tomorrow.', {
        op,
        plan: ctx.plan,
        limit: limits.dailyCap,
        scope: 'day',
      });
    }
    if (used >= limits[op]) {
      throw new HttpsError(
        'resource-exhausted',
        ctx.plan === 'free'
          ? 'You have used your free allowance for this month. Upgrade to Pro for unlimited use.'
          : 'Monthly fair-use limit reached. Contact support if you need more.',
        { op, plan: ctx.plan, limit: limits[op], used, scope: 'month' },
      );
    }
    counts[op] = used + 1;
    tx.set(
      ref,
      {
        month,
        day,
        counts,
        dayCount: dayCount + 1,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

/**
 * Gives back one unit of `op` after a server-side failure, so a user is not
 * charged for a call that produced nothing. Best-effort: a failure here is
 * logged, never surfaced.
 */
export async function refundQuota(ctx: AuthedContext, op: QuotaOp): Promise<void> {
  const ref = getFirestore().doc(`users/${ctx.uid}/private/usage`);
  try {
    await getFirestore().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = (snap.data() ?? {}) as { counts?: Partial<Record<QuotaOp, number>>; dayCount?: number };
      const counts = { ...(data.counts ?? {}) };
      counts[op] = Math.max(0, (counts[op] ?? 0) - 1);
      tx.set(ref, { counts, dayCount: Math.max(0, (data.dayCount ?? 0) - 1) }, { merge: true });
    });
  } catch (err) {
    logger.warn('quota.refund_failed', { uid: ctx.uid, op, err: String(err) });
  }
}
