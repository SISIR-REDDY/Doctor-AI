import { z } from 'zod';
import type { Content } from '@google/genai';
import { generate, type InlineFile } from '../ai/gemini';
import { coverageChatSystem, healthChatSystem, legacyGenerateSystem, PROMPT_VERSION } from '../ai/prompts';
import { regionOf } from '../regions';

export const chatInput = z.object({
  mode: z.enum(['coverage', 'health']).default('coverage'),
  region: z.string().length(2).default('US'),
  messages: z
    .array(z.object({ role: z.enum(['user', 'assistant']), content: z.string().max(6000) }))
    .min(1)
    .max(24),
  /** Summaries of the user's documents / cases / policies (built client-side). */
  // Must stay ≥ the client's ChatContextBuilder._maxChars (14 000).
  context: z.string().max(16000).default(''),
  profileSummary: z.string().max(2000).default(''),
});
export type ChatInput = z.infer<typeof chatInput>;

export async function chat(apiKey: string, input: ChatInput) {
  const region = regionOf(input.region);
  const last = input.messages[input.messages.length - 1];
  const history: Content[] = input.messages.slice(0, -1).map((m) => ({
    role: m.role === 'user' ? 'user' : 'model',
    parts: [{ text: m.content }],
  }));
  const res = await generate<string>({
    apiKey,
    tier: 'fast',
    system: input.mode === 'coverage' ? coverageChatSystem(region, input.context) : healthChatSystem(input.profileSummary),
    text: last.content,
    history,
    temperature: 0.4,
    maxOutputTokens: 1536,
  });
  return { reply: res.data, model: res.model, promptVersion: PROMPT_VERSION };
}

/**
 * Transitional passthrough for screens that still build their own prompt
 * (records summary, symptom trends, legacy claim report). Keeps the key
 * server-side today; each caller is being migrated to a typed task.
 */
export const generateInput = z.object({
  prompt: z.string().min(1).max(30000),
  files: z
    .array(z.object({ mimeType: z.string().regex(/^(image\/(jpeg|png|webp|heic|heif)|application\/pdf)$/), data: z.string().min(16) }))
    .max(12)
    .default([]),
  json: z.boolean().default(false),
});
export type GenerateInput = z.infer<typeof generateInput>;

export async function legacyGenerate(apiKey: string, input: GenerateInput) {
  const files: InlineFile[] = input.files;
  const res = await generate<string>({
    apiKey,
    tier: files.length ? 'fast' : 'smart',
    system: legacyGenerateSystem(),
    text: input.prompt,
    files,
    temperature: 0.4,
    maxOutputTokens: 6144,
  });
  return { text: res.data, model: res.model, promptVersion: PROMPT_VERSION };
}
