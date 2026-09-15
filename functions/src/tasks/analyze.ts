import { z } from 'zod';
import { HttpsError } from 'firebase-functions/v2/https';
import { getStorage } from 'firebase-admin/storage';
import { generate, type InlineFile } from '../ai/gemini';
import { classifySchema, billSchema, eobSchema, denialSchema, policySchema, recordSchema, DOC_TYPES, type DocType } from '../ai/schemas';
import { classifySystem, extractSystem, PROMPT_VERSION } from '../ai/prompts';
import { regionOf } from '../regions';

const MAX_FILES = 12;
const MAX_INLINE_BYTES = 9 * 1024 * 1024; // callable payload headroom

const fileSchema = z.object({
  mimeType: z.string().regex(/^(image\/(jpeg|png|webp|heic|heif)|application\/pdf)$/),
  data: z.string().min(16),
});

export const analyzeInput = z.object({
  docType: z.enum(['auto', ...DOC_TYPES]).default('auto'),
  region: z.string().min(2).max(2).default('US'),
  files: z.array(fileSchema).max(MAX_FILES).default([]),
  /** Alternative to inline files: paths in the default Storage bucket owned by the caller. */
  storagePaths: z.array(z.string().min(1)).max(MAX_FILES).default([]),
  /** Free-text hints from the user, e.g. "this is my ER visit from March". */
  hints: z.string().max(2000).default(''),
});
export type AnalyzeInput = z.infer<typeof analyzeInput>;

export interface AnalyzeOutput {
  documentType: DocType;
  classificationConfidence: number;
  language: string;
  data: Record<string, unknown>;
  model: string;
  promptVersion: string;
}

const SCHEMAS = {
  bill: billSchema,
  eob: eobSchema,
  denial: denialSchema,
  policy: policySchema,
  record: recordSchema,
  other: recordSchema,
} as const;

export async function analyzeDocument(uid: string, apiKey: string, input: AnalyzeInput): Promise<AnalyzeOutput> {
  const region = regionOf(input.region);
  const files = await collectFiles(uid, input);
  if (files.length === 0) {
    throw new HttpsError('invalid-argument', 'Attach at least one image or PDF.');
  }
  const hintText = input.hints ? `\nUser hint: ${input.hints}` : '';

  let docType: DocType;
  let classificationConfidence = 1;
  let language = 'en';
  if (input.docType === 'auto') {
    const cls = await generate<{ documentType: DocType; confidence: number; language?: string }>({
      apiKey,
      tier: 'fast',
      system: classifySystem(),
      text: `Classify this document.${hintText}`,
      files,
      jsonSchema: classifySchema,
      temperature: 0,
      maxOutputTokens: 256,
    });
    docType = DOC_TYPES.includes(cls.data.documentType) ? cls.data.documentType : 'other';
    classificationConfidence = Number(cls.data.confidence ?? 0);
    language = cls.data.language || 'en';
  } else {
    docType = input.docType;
  }

  const res = await generate<Record<string, unknown>>({
    apiKey,
    tier: 'fast',
    system: extractSystem(docType, region),
    text: `Extract the ${docType} data from the attached ${files.length} file(s).${hintText}`,
    files,
    jsonSchema: SCHEMAS[docType],
    temperature: 0,
    maxOutputTokens: 8192,
  });

  return {
    documentType: docType,
    classificationConfidence,
    language,
    data: res.data,
    model: res.model,
    promptVersion: PROMPT_VERSION,
  };
}

async function collectFiles(uid: string, input: AnalyzeInput): Promise<InlineFile[]> {
  const files: InlineFile[] = [...input.files];
  let bytes = files.reduce((n, f) => n + Math.ceil((f.data.length * 3) / 4), 0);
  if (bytes > MAX_INLINE_BYTES) {
    throw new HttpsError('invalid-argument', 'Attachments are too large. Upload fewer or smaller pages.');
  }
  for (const path of input.storagePaths) {
    // Only the owner's own uploads may be read server-side.
    if (!path.startsWith(`document_scans/${uid}/`) && !path.startsWith(`uploads/${uid}/`)) {
      throw new HttpsError('permission-denied', 'Storage path is not owned by the caller.');
    }
    const file = getStorage().bucket().file(path);
    const [meta] = await file.getMetadata();
    const mime = String(meta.contentType ?? 'application/octet-stream');
    if (!/^(image\/(jpeg|png|webp|heic|heif)|application\/pdf)$/.test(mime)) {
      throw new HttpsError('invalid-argument', `Unsupported file type: ${mime}`);
    }
    const [buf] = await file.download();
    bytes += buf.length;
    if (bytes > 20 * 1024 * 1024) {
      throw new HttpsError('invalid-argument', 'Total attachment size exceeds 20 MB.');
    }
    files.push({ mimeType: mime, data: buf.toString('base64') });
  }
  return files;
}
