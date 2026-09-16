import { z } from 'zod';
import { generate } from '../ai/gemini';
import { auditSchema } from '../ai/schemas';
import { auditSystem, PROMPT_VERSION } from '../ai/prompts';
import { regionOf } from '../regions';
import { benchmarkTable, lookupBenchmarks, normalizeCode, referencePrice, type Benchmark } from '../benchmarks';

const lineItem = z.object({
  code: z.string().default(''),
  codeSystem: z.string().default(''),
  modifier: z.string().default(''),
  description: z.string().default(''),
  dateOfService: z.string().default(''),
  quantity: z.number().default(1),
  unitPrice: z.number().default(0),
  amount: z.number().default(0),
  category: z.string().default('other'),
});

const expense = z.object({
  id: z.string(),
  vendor: z.string().default(''),
  date: z.string().default(''),
  category: z.string().default('other'),
  amount: z.number().default(0),
  note: z.string().default(''),
  lineItems: z.array(lineItem).default([]),
  /** Legacy free-text line items captured before structured extraction. */
  lineItemsText: z.string().default(''),
});

export const auditInput = z.object({
  region: z.string().length(2).default('US'),
  currency: z.string().default(''),
  caseType: z.string().default('outpatient'),
  diagnosis: z.string().default(''),
  providerName: z.string().default(''),
  setting: z.enum(['office', 'hospital', 'unknown']).default('unknown'),
  expenses: z.array(expense).min(1).max(60),
  /** Optional structured EOB (from analyzeDocument) for balance-billing checks. */
  eob: z.record(z.unknown()).optional(),
  /** Optional policy cost-sharing (from analyzeDocument / policy screen). */
  policy: z.record(z.unknown()).optional(),
  /** Answers to earlier questionsForUser. */
  userNotes: z.string().max(4000).default(''),
});
export type AuditInput = z.infer<typeof auditInput>;

export interface DeterministicFinding {
  type: 'duplicate' | 'overpriced' | 'quantity' | 'math_error';
  detail: string;
  expenseIds: string[];
  amountAtIssue: number;
  benchmarkCode?: string;
  benchmarkReferencePrice?: number;
  benchmarkRatio?: number;
}

export async function auditBills(apiKey: string, input: AuditInput) {
  const region = regionOf(input.region);
  const currency = input.currency || region.currencyCode;
  const setting = input.setting === 'unknown' ? (input.caseType === 'inpatient' || input.caseType === 'emergency' ? 'hospital' : 'office') : input.setting;

  const codes = input.expenses.flatMap((e) => e.lineItems.map((l) => normalizeCode(l.code))).filter(Boolean);
  const benchmarks = await lookupBenchmarks(region, codes);
  const deterministic = runRules(input, benchmarks, setting);

  const itemized = input.expenses
    .map((e) => {
      const head = `Expense ${e.id} · ${e.category} · ${e.vendor || 'unknown provider'} · ${e.date || 'no date'} · total ${currency} ${e.amount.toFixed(2)}${e.note ? ` · note: ${e.note}` : ''}`;
      const lines = e.lineItems.length
        ? e.lineItems
            .map(
              (l) =>
                `    • [${l.code || 'no code'}${l.modifier ? `-${l.modifier}` : ''}] ${l.description} · ${l.dateOfService || ''} · qty ${l.quantity} × ${currency} ${l.unitPrice.toFixed(2)} = ${currency} ${l.amount.toFixed(2)}`,
            )
            .join('\n')
        : e.lineItemsText
          ? e.lineItemsText
              .split('\n')
              .filter((s) => s.trim())
              .map((s) => `    • ${s.trim()}`)
              .join('\n')
          : '    • (not itemized)';
      return `${head}\n${lines}`;
    })
    .join('\n');

  const detText = deterministic.length
    ? deterministic.map((d, i) => `D${i + 1} [${d.type}] ${d.detail} (expenses: ${d.expenseIds.join(', ')}; amount at issue ${currency} ${d.amountAtIssue.toFixed(2)})`).join('\n')
    : '(none)';

  const total = input.expenses.reduce((n, e) => n + e.amount, 0);
  const text = `CASE
Type: ${input.caseType} · setting: ${setting}
Diagnosis / reason: ${input.diagnosis || 'not specified'}
Provider: ${input.providerName || 'not specified'}
Currency: ${currency} · Total billed: ${currency} ${total.toFixed(2)}

ITEMIZED BILLS
${itemized}

DETERMINISTIC FINDINGS (pre-computed, verify and refine)
${detText}

BENCHMARK REFERENCE PRICES (${region.benchmarkSource ?? 'none for this country'})
${benchmarkTable(benchmarks, currency)}

${input.eob ? `EOB DATA\n${JSON.stringify(input.eob).slice(0, 6000)}\n` : ''}${input.policy ? `POLICY COST-SHARING\n${JSON.stringify(input.policy).slice(0, 3000)}\n` : ''}${input.userNotes ? `USER NOTES\n${input.userNotes}\n` : ''}
Produce the audit report now. Use ${currency} for all amounts.`;

  const res = await generate<Record<string, unknown>>({
    apiKey,
    tier: 'smart',
    system: auditSystem(region),
    text,
    jsonSchema: auditSchema,
    temperature: 0.2,
    maxOutputTokens: 8192,
  });

  return {
    report: res.data,
    benchmarksUsed: Array.from(benchmarks.values()).map((b) => ({ code: b.code, reference: referencePrice(b, setting), approximate: b.approximate, year: b.year })),
    deterministicCount: deterministic.length,
    model: res.model,
    promptVersion: PROMPT_VERSION,
    currency,
  };
}

/** Cheap, explainable checks that do not depend on the model. */
export function runRules(input: AuditInput, benchmarks: Map<string, Benchmark>, setting: 'office' | 'hospital'): DeterministicFinding[] {
  const out: DeterministicFinding[] = [];
  const seen = new Map<string, { expenseId: string; amount: number; desc: string }>();

  for (const e of input.expenses) {
    let lineSum = 0;
    for (const l of e.lineItems) {
      lineSum += l.amount;
      const code = normalizeCode(l.code);
      const key = `${code || l.description.toLowerCase().trim()}|${l.dateOfService}|${l.amount.toFixed(2)}`;
      // Duplicate: identical code/description + date + amount, and not a multi-unit line.
      if (l.quantity <= 1 && l.amount > 0) {
        const prev = seen.get(key);
        if (prev) {
          out.push({
            type: 'duplicate',
            detail: `"${l.description}" (${code || 'no code'}) on ${l.dateOfService || 'same date'} appears more than once at ${l.amount.toFixed(2)}.`,
            expenseIds: Array.from(new Set([prev.expenseId, e.id])),
            amountAtIssue: l.amount,
          });
        } else {
          seen.set(key, { expenseId: e.id, amount: l.amount, desc: l.description });
        }
      }
      // Quantity sanity for evaluation & management codes (one visit per day).
      if (/^99(2\d\d|3\d\d|4\d\d)$/.test(code) && l.quantity > 1) {
        out.push({
          type: 'quantity',
          detail: `Visit code ${code} billed ${l.quantity} times on ${l.dateOfService || 'one date'}; usually one per day.`,
          expenseIds: [e.id],
          amountAtIssue: l.amount,
        });
      }
      // Benchmark ratio.
      const b = code ? benchmarks.get(code) : undefined;
      if (b) {
        const ref = referencePrice(b, setting);
        const unit = l.unitPrice > 0 ? l.unitPrice : l.quantity > 0 ? l.amount / l.quantity : l.amount;
        if (ref > 0 && unit > 0) {
          const ratio = unit / ref;
          if (ratio >= 3) {
            out.push({
              type: 'overpriced',
              detail: `${code} billed at ${unit.toFixed(2)} per unit vs ${b.approximate ? '≈' : ''}${ref.toFixed(2)} Medicare reference (${ratio.toFixed(1)}x).`,
              expenseIds: [e.id],
              amountAtIssue: l.amount,
              benchmarkCode: code,
              benchmarkReferencePrice: ref,
              benchmarkRatio: Number(ratio.toFixed(2)),
            });
          }
        }
      }
    }
    // Line items should add up to the expense total (allow rounding).
    if (e.lineItems.length > 1 && e.amount > 0 && Math.abs(lineSum - e.amount) > Math.max(1, e.amount * 0.02)) {
      out.push({
        type: 'math_error',
        detail: `Line items sum to ${lineSum.toFixed(2)} but the bill total is ${e.amount.toFixed(2)}.`,
        expenseIds: [e.id],
        amountAtIssue: Math.abs(lineSum - e.amount),
      });
    }
  }
  return out;
}
