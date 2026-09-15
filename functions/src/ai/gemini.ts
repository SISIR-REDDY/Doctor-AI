import {
  GoogleGenAI,
  HarmBlockThreshold,
  HarmCategory,
  type Content,
  type Part,
  type Schema,
} from '@google/genai';
import { HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { getRuntimeConfig } from '../config';

export type ModelTier = 'fast' | 'smart';

export interface InlineFile {
  /** e.g. image/jpeg, image/png, application/pdf */
  mimeType: string;
  /** base64 payload (no data: prefix) */
  data: string;
}

export interface GenerateOptions {
  apiKey: string;
  tier: ModelTier;
  system: string;
  /** Plain user text (goes first). */
  text: string;
  files?: InlineFile[];
  /** Prior turns for chat-style tasks. */
  history?: Content[];
  /** When set, the model is forced to return JSON matching this schema. */
  jsonSchema?: Schema;
  temperature?: number;
  maxOutputTokens?: number;
}

export interface GenerateResult<T> {
  data: T;
  model: string;
  /** Raw text (useful for logging / debugging JSON parse failures). */
  raw: string;
  usage?: { promptTokens?: number; outputTokens?: number };
}

const SAFETY = [
  HarmCategory.HARM_CATEGORY_HARASSMENT,
  HarmCategory.HARM_CATEGORY_HATE_SPEECH,
  HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
  HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
].map((category) => ({
  category,
  // Bills, lab reports and denial letters routinely mention drugs, injuries
  // and procedures; the default thresholds block legitimate health content.
  threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH,
}));

/**
 * Calls Gemini with an ordered model fallback (configurable at runtime via
 * `app_runtime/config.models`). JSON mode is enforced through responseSchema
 * so the client never has to scrape fenced code blocks again.
 */
export async function generate<T = string>(opts: GenerateOptions): Promise<GenerateResult<T>> {
  const cfg = await getRuntimeConfig();
  const models = opts.tier === 'smart' ? cfg.models.smart : cfg.models.fast;
  const ai = new GoogleGenAI({ apiKey: opts.apiKey });

  const parts: Part[] = [{ text: opts.text }];
  for (const f of opts.files ?? []) {
    if (!f.data) continue;
    parts.push({ inlineData: { mimeType: f.mimeType, data: f.data } });
  }
  const contents: Content[] = [...(opts.history ?? []), { role: 'user', parts }];

  let lastError: unknown;
  for (const model of models) {
    try {
      const started = Date.now();
      const isFlash = model.includes('flash');
      const response = await ai.models.generateContent({
        model,
        contents,
        config: {
          systemInstruction: opts.system,
          temperature: opts.temperature ?? 0.3,
          maxOutputTokens: opts.maxOutputTokens ?? 8192,
          safetySettings: SAFETY,
          ...(opts.jsonSchema
            ? { responseMimeType: 'application/json', responseSchema: opts.jsonSchema }
            : {}),
          // Extraction / chat on flash models: skip thinking for latency+cost.
          // Pro models cannot disable thinking, so only touch flash tiers.
          ...(opts.tier === 'fast' && isFlash ? { thinkingConfig: { thinkingBudget: 0 } } : {}),
        },
      });

      const raw = (response.text ?? '').trim();
      if (!raw) {
        const reason = response.candidates?.[0]?.finishReason ?? 'EMPTY';
        lastError = new Error(`${model}: empty response (${reason})`);
        logger.warn('gemini.empty', { model, reason });
        continue;
      }
      const usage = response.usageMetadata
        ? {
            promptTokens: response.usageMetadata.promptTokenCount,
            outputTokens: response.usageMetadata.candidatesTokenCount,
          }
        : undefined;
      logger.info('gemini.ok', { model, ms: Date.now() - started, ...usage });

      if (opts.jsonSchema) {
        const parsed = safeParseJson(raw);
        if (parsed === undefined) {
          lastError = new Error(`${model}: invalid JSON`);
          logger.warn('gemini.badjson', { model, head: raw.slice(0, 200) });
          continue;
        }
        return { data: parsed as T, model, raw, usage };
      }
      return { data: raw as unknown as T, model, raw, usage };
    } catch (err) {
      lastError = err;
      const msg = String((err as Error)?.message ?? err);
      logger.warn('gemini.fail', { model, msg: msg.slice(0, 300) });
      // Auth problems will not fix themselves on another model.
      if (/API key|PERMISSION_DENIED|401|403/.test(msg)) {
        throw new HttpsError('failed-precondition', 'AI provider key is invalid or unauthorised.');
      }
      if (/429|RESOURCE_EXHAUSTED|quota/i.test(msg)) {
        // Try the next model in the chain — quotas are per model.
        continue;
      }
    }
  }
  const msg = String((lastError as Error)?.message ?? lastError ?? 'unknown');
  throw new HttpsError('unavailable', `The AI service is busy or unavailable. Please try again. (${msg.slice(0, 120)})`);
}

/** Tolerates fenced ```json blocks and stray prose around a JSON object. */
export function safeParseJson(raw: string): unknown {
  const candidates = [raw];
  const fence = raw.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence) candidates.unshift(fence[1]);
  const first = raw.indexOf('{');
  const last = raw.lastIndexOf('}');
  if (first >= 0 && last > first) candidates.push(raw.slice(first, last + 1));
  for (const c of candidates) {
    try {
      return JSON.parse(c);
    } catch {
      /* try next */
    }
  }
  return undefined;
}
