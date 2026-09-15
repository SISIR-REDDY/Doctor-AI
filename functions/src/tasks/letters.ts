import { z } from 'zod';
import { generate } from '../ai/gemini';
import { denialExplanationSchema, letterSchema } from '../ai/schemas';
import { denialSystem, letterSystem, PROMPT_VERSION, type LetterKind } from '../ai/prompts';
import { regionOf } from '../regions';

const LETTER_KINDS: [LetterKind, ...LetterKind[]] = [
  'appeal',
  'dispute',
  'itemized_request',
  'charity_care',
  'medical_necessity',
  'regulator_complaint',
  'ombudsman_complaint',
  'records_request',
];

/** Everything the letter might reference. All optional; unknowns become placeholders. */
export const letterInput = z.object({
  region: z.string().length(2).default('US'),
  kind: z.enum(LETTER_KINDS),
  context: z
    .object({
      patientName: z.string().default(''),
      policyholderName: z.string().default(''),
      insurerName: z.string().default(''),
      providerName: z.string().default(''),
      policyNumber: z.string().default(''),
      memberId: z.string().default(''),
      claimNumber: z.string().default(''),
      accountNumber: z.string().default(''),
      dateOfService: z.string().default(''),
      denialDate: z.string().default(''),
      diagnosis: z.string().default(''),
      serviceDescription: z.string().default(''),
      amount: z.number().default(0),
      currency: z.string().default(''),
      denialReasonCategory: z.string().default(''),
      denialReasonText: z.string().default(''),
      policyClausesCited: z.array(z.string()).default([]),
      /** Audit findings the user selected to dispute (title + disputeParagraph + amounts). */
      findings: z.array(z.record(z.unknown())).default([]),
      /** Arguments from explainDenial the user wants to use. */
      argumentsToUse: z.array(z.string()).default([]),
      evidenceAvailable: z.array(z.string()).default([]),
      householdSize: z.number().default(0),
      annualIncome: z.number().default(0),
      extraInstructions: z.string().max(3000).default(''),
    })
    .default({}),
});
export type LetterInput = z.infer<typeof letterInput>;

export async function draftLetter(apiKey: string, input: LetterInput) {
  const region = regionOf(input.region);
  const c = input.context;
  const currency = c.currency || region.currencyCode;
  const facts = Object.entries({
    'Patient': c.patientName,
    'Policyholder': c.policyholderName,
    'Insurer': c.insurerName,
    'Provider / hospital': c.providerName,
    'Policy number': c.policyNumber,
    'Member ID': c.memberId,
    'Claim number': c.claimNumber,
    'Account number': c.accountNumber,
    'Date(s) of service': c.dateOfService,
    'Denial date': c.denialDate,
    'Diagnosis': c.diagnosis,
    'Service': c.serviceDescription,
    'Amount': c.amount > 0 ? `${currency} ${c.amount.toFixed(2)}` : '',
    'Denial reason (category)': c.denialReasonCategory,
    'Denial reason (text)': c.denialReasonText,
    'Policy clauses cited': c.policyClausesCited.join('; '),
    'Household size': c.householdSize > 0 ? String(c.householdSize) : '',
    'Annual household income': c.annualIncome > 0 ? `${currency} ${c.annualIncome}` : '',
  })
    .filter(([, v]) => v && String(v).trim())
    .map(([k, v]) => `- ${k}: ${v}`)
    .join('\n');

  const findings = c.findings.length
    ? `\nDISPUTED ITEMS (from the audit; include each with its amount):\n${c.findings
        .map((f, i) => `${i + 1}. ${String(f.title ?? '')} — amount at issue ${currency} ${Number(f.amountAtIssue ?? 0).toFixed(2)}. ${String(f.disputeParagraph ?? f.explanation ?? '')}`)
        .join('\n')}`
    : '';
  const args = c.argumentsToUse.length ? `\nARGUMENTS TO MAKE:\n${c.argumentsToUse.map((a) => `- ${a}`).join('\n')}` : '';
  const evidence = c.evidenceAvailable.length ? `\nEVIDENCE THE USER CAN ENCLOSE:\n${c.evidenceAvailable.map((a) => `- ${a}`).join('\n')}` : '';
  const extra = c.extraInstructions ? `\nUSER INSTRUCTIONS:\n${c.extraInstructions}` : '';

  const res = await generate<Record<string, unknown>>({
    apiKey,
    tier: 'smart',
    system: letterSystem(input.kind, region),
    text: `Draft the ${input.kind} letter using these facts. Use ${currency} for amounts.\n\nFACTS:\n${facts || '- (none provided — use placeholders)'}${findings}${args}${evidence}${extra}`,
    jsonSchema: letterSchema,
    temperature: 0.35,
    maxOutputTokens: 6144,
  });
  return { letter: res.data, model: res.model, promptVersion: PROMPT_VERSION, kind: input.kind };
}

export const explainInput = z.object({
  region: z.string().length(2).default('US'),
  denial: z.record(z.unknown()),
  policy: z.record(z.unknown()).optional(),
  userNotes: z.string().max(4000).default(''),
});
export type ExplainInput = z.infer<typeof explainInput>;

export async function explainDenial(apiKey: string, input: ExplainInput) {
  const region = regionOf(input.region);
  const res = await generate<Record<string, unknown>>({
    apiKey,
    tier: 'smart',
    system: denialSystem(region),
    text: `DENIAL (structured, extracted from the letter):\n${JSON.stringify(input.denial, null, 1).slice(0, 8000)}\n\n${
      input.policy ? `POLICY:\n${JSON.stringify(input.policy, null, 1).slice(0, 4000)}\n\n` : ''
    }${input.userNotes ? `USER NOTES:\n${input.userNotes}\n\n` : ''}Explain this denial and how to challenge it.`,
    jsonSchema: denialExplanationSchema,
    temperature: 0.3,
    maxOutputTokens: 6144,
  });
  return { explanation: res.data, model: res.model, promptVersion: PROMPT_VERSION };
}
