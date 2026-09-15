import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';

/**
 * Runtime configuration read from Firestore `app_runtime/config` (writable
 * only from the console / admin SDK — clients cannot read or write it).
 *
 * Lets you change models, quotas and beta flags without an app release.
 */
export interface RuntimeConfig {
  /** Ordered fallback chains. First entry is tried first. */
  models: { fast: string[]; smart: string[] };
  /** Beta switch: treat every signed-in user as Pro (no purchase needed). */
  everyonePro: boolean;
  /** Reject calls without a valid App Check token. Turn on after you enable App Check in the console. */
  enforceAppCheck: boolean;
  /** Monthly per-operation limits per plan. */
  limits: Record<Plan, Record<QuotaOp, number> & { dailyCap: number }>;
  /** Minimum app build allowed to call the AI (0 = any). */
  minBuild: number;
}

export type Plan = 'free' | 'pro';
export type QuotaOp = 'analyze' | 'audit' | 'letter' | 'explain' | 'chat' | 'generate';

export const DEFAULT_CONFIG: RuntimeConfig = {
  models: {
    fast: ['gemini-2.5-flash', 'gemini-2.5-flash-lite', 'gemini-2.0-flash'],
    smart: ['gemini-2.5-pro', 'gemini-2.5-flash', 'gemini-2.0-flash'],
  },
  everyonePro: false,
  enforceAppCheck: false,
  limits: {
    free: { analyze: 6, audit: 1, letter: 1, explain: 2, chat: 20, generate: 20, dailyCap: 60 },
    pro: { analyze: 300, audit: 60, letter: 60, explain: 60, chat: 600, generate: 300, dailyCap: 250 },
  },
  minBuild: 0,
};

let cached: { value: RuntimeConfig; at: number } | null = null;
const TTL_MS = 60_000;

export async function getRuntimeConfig(): Promise<RuntimeConfig> {
  if (cached && Date.now() - cached.at < TTL_MS) return cached.value;
  let value = DEFAULT_CONFIG;
  try {
    const snap = await getFirestore().doc('app_runtime/config').get();
    if (snap.exists) value = mergeConfig(snap.data() ?? {});
  } catch (err) {
    logger.warn('config.read_failed', { err: String(err) });
  }
  cached = { value, at: Date.now() };
  return value;
}

function mergeConfig(raw: Record<string, unknown>): RuntimeConfig {
  const models = (raw.models ?? {}) as Partial<RuntimeConfig['models']>;
  const limits = (raw.limits ?? {}) as Partial<RuntimeConfig['limits']>;
  return {
    models: {
      fast: asStringList(models.fast) ?? DEFAULT_CONFIG.models.fast,
      smart: asStringList(models.smart) ?? DEFAULT_CONFIG.models.smart,
    },
    everyonePro: raw.everyonePro === true,
    enforceAppCheck: raw.enforceAppCheck === true,
    limits: {
      free: { ...DEFAULT_CONFIG.limits.free, ...(limits.free ?? {}) },
      pro: { ...DEFAULT_CONFIG.limits.pro, ...(limits.pro ?? {}) },
    },
    minBuild: typeof raw.minBuild === 'number' ? raw.minBuild : 0,
  };
}

function asStringList(v: unknown): string[] | undefined {
  if (!Array.isArray(v)) return undefined;
  const list = v.filter((x): x is string => typeof x === 'string' && x.length > 0);
  return list.length ? list : undefined;
}
