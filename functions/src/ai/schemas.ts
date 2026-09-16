import { Type, type Schema } from '@google/genai';

/**
 * Gemini response schemas. Keep property names stable — the Flutter models
 * (lib/models/advocate_models.dart) mirror them field-for-field.
 */

const str = (description?: string): Schema => ({ type: Type.STRING, description });
const num = (description?: string): Schema => ({ type: Type.NUMBER, description });
const bool = (description?: string): Schema => ({ type: Type.BOOLEAN, description });
const strList = (description?: string): Schema => ({ type: Type.ARRAY, items: { type: Type.STRING }, description });

export const DOC_TYPES = ['bill', 'eob', 'denial', 'policy', 'record', 'other'] as const;
export type DocType = (typeof DOC_TYPES)[number];

export const classifySchema: Schema = {
  type: Type.OBJECT,
  properties: {
    documentType: { type: Type.STRING, enum: [...DOC_TYPES], description: 'What kind of document this is.' },
    confidence: num('0-1'),
    language: str('BCP-47 language code of the document, e.g. en, es, de, hi'),
  },
  required: ['documentType', 'confidence'],
};

const lineItem: Schema = {
  type: Type.OBJECT,
  properties: {
    code: str('Billing code exactly as printed (CPT/HCPCS/MBS/revenue/tariff code) or empty string.'),
    codeSystem: { type: Type.STRING, enum: ['CPT', 'HCPCS', 'REV', 'NDC', 'MBS', 'ICD10', 'TARIFF', 'OTHER', ''] },
    modifier: str('Modifier(s) if printed, e.g. 25, 59, TC.'),
    description: str('Service description as printed, lightly cleaned.'),
    dateOfService: str('YYYY-MM-DD or empty string.'),
    quantity: num('Units/quantity; 1 if not shown.'),
    unitPrice: num('Price per unit; equals amount when quantity is 1. 0 if unknown.'),
    amount: num('Line total charged.'),
    category: {
      type: Type.STRING,
      enum: ['consultation', 'procedure', 'surgery', 'room', 'icu', 'lab', 'imaging', 'pharmacy', 'supplies', 'emergency', 'therapy', 'dental', 'vision', 'ambulance', 'facility_fee', 'other'],
    },
  },
  required: ['description', 'amount', 'quantity', 'category'],
};

export const billSchema: Schema = {
  type: Type.OBJECT,
  properties: {
    providerName: str('Hospital / clinic / doctor / pharmacy name.'),
    providerAddress: str(),
    providerPhone: str(),
    accountNumber: str('Patient account / invoice / bill number.'),
    patientName: str(),
    invoiceDate: str('YYYY-MM-DD or empty.'),
    dateOfService: str('First date of service YYYY-MM-DD or empty.'),
    dateOfServiceEnd: str('Discharge / last date YYYY-MM-DD or empty.'),
    currency: str('ISO 4217 code detected from the document, e.g. USD, GBP, INR.'),
    caseType: { type: Type.STRING, enum: ['inpatient', 'outpatient', 'emergency', 'pharmacy', 'dental', 'other'] },
    totalBilled: num('Sum of all charges before payments/adjustments.'),
    insurancePaid: num('Amount insurance already paid, 0 if none shown.'),
    adjustments: num('Discounts/adjustments, 0 if none.'),
    patientResponsibility: num('Amount the patient owes per the document, 0 if not shown.'),
    lineItems: { type: Type.ARRAY, items: lineItem },
    diagnoses: strList('Diagnoses / ICD codes printed on the document.'),
    isItemized: bool('True if individual line items with prices are present.'),
    summary: str('2-3 sentence plain-language description of this bill for the patient.'),
    confidence: num('0-1 overall extraction confidence.'),
    warnings: strList('Anything unreadable, cut off, or ambiguous.'),
  },
  required: ['providerName', 'currency', 'totalBilled', 'lineItems', 'isItemized', 'summary', 'confidence', 'warnings', 'caseType'],
};

const eobLine: Schema = {
  type: Type.OBJECT,
  properties: {
    code: str(),
    description: str(),
    dateOfService: str('YYYY-MM-DD or empty'),
    billed: num(),
    allowed: num('Allowed / eligible amount; 0 if not shown.'),
    planPaid: num(),
    deductible: num(),
    copay: num(),
    coinsurance: num(),
    notCovered: num('Amount denied or not covered.'),
    patientResponsibility: num(),
    remarkCodes: strList('Remark / reason codes printed for this line (e.g. CO-45, PR-1, N130).'),
  },
  required: ['description', 'billed', 'patientResponsibility'],
};

export const eobSchema: Schema = {
  type: Type.OBJECT,
  properties: {
    insurerName: str(),
    memberId: str(),
    claimNumber: str(),
    patientName: str(),
    providerName: str(),
    dateOfService: str('YYYY-MM-DD or empty'),
    processedDate: str('YYYY-MM-DD or empty'),
    currency: str('ISO 4217'),
    networkStatus: { type: Type.STRING, enum: ['in_network', 'out_of_network', 'unknown'] },
    lines: { type: Type.ARRAY, items: eobLine },
    totalBilled: num(),
    totalAllowed: num(),
    totalPlanPaid: num(),
    totalPatientResponsibility: num(),
    deductibleAppliedThisClaim: num(),
    deductibleRemaining: num('If the statement shows year-to-date deductible remaining; else 0.'),
    outOfPocketRemaining: num('If shown; else 0.'),
    denialReasons: strList('Any reason text explaining denied or reduced amounts.'),
    appealRightsText: str('Verbatim appeal instructions / deadline text if present.'),
    appealDeadline: str('YYYY-MM-DD if a specific date is printed, else empty.'),
    summary: str('Plain-language explanation of what this EOB says the patient owes and why.'),
    confidence: num(),
    warnings: strList(),
  },
  required: ['insurerName', 'currency', 'lines', 'totalBilled', 'totalPatientResponsibility', 'summary', 'confidence', 'warnings', 'networkStatus'],
};

export const DENIAL_REASONS = [
  'medical_necessity',
  'prior_authorization',
  'not_covered',
  'out_of_network',
  'coding_error',
  'timely_filing',
  'pre_existing',
  'experimental',
  'coordination_of_benefits',
  'eligibility',
  'documentation',
  'waiting_period',
  'sub_limit',
  'other',
] as const;

export const denialSchema: Schema = {
  type: Type.OBJECT,
  properties: {
    insurerName: str(),
    memberId: str(),
    claimNumber: str(),
    referenceNumber: str('Denial / case / authorization reference if different from claim number.'),
    patientName: str(),
    providerName: str(),
    serviceDescription: str('What was denied (procedure, drug, admission…).'),
    dateOfService: str('YYYY-MM-DD or empty'),
    denialDate: str('Date of the letter YYYY-MM-DD or empty'),
    amountDenied: num('0 if not stated'),
    currency: str('ISO 4217'),
    reasonCategory: { type: Type.STRING, enum: [...DENIAL_REASONS] },
    reasonText: str('The insurer’s stated reason, verbatim or closely paraphrased.'),
    policyClausesCited: strList('Policy sections / clauses / codes the insurer cites.'),
    appealDeadline: str('YYYY-MM-DD if a specific date is printed, else empty.'),
    appealDeadlineText: str('Deadline as worded in the letter, e.g. "within 180 days of this notice".'),
    appealLevels: strList('Appeal levels or bodies mentioned (internal, external review, ombudsman…).'),
    appealAddress: str(),
    appealFax: str(),
    appealEmail: str(),
    appealPhone: str(),
    externalReviewMentioned: bool(),
    isUrgent: bool('True if the letter concerns ongoing / urgent treatment.'),
    summary: str('Plain-language explanation of the denial for the patient (3-4 sentences).'),
    confidence: num(),
    warnings: strList(),
  },
  required: ['insurerName', 'reasonCategory', 'reasonText', 'currency', 'summary', 'confidence', 'warnings', 'externalReviewMentioned', 'isUrgent'],
};

export const policySchema: Schema = {
  type: Type.OBJECT,
  properties: {
    insurerName: str(),
    planName: str(),
    policyNumber: str(),
    memberId: str(),
    groupNumber: str(),
    policyType: { type: Type.STRING, enum: ['health', 'dental', 'vision', 'travel', 'life', 'term', 'critical_illness', 'other'] },
    country: str('ISO 3166 alpha-2 if evident, else empty.'),
    currency: str('ISO 4217'),
    coverageAmount: num('Sum insured / annual maximum; 0 if not applicable.'),
    premiumAmount: num(),
    premiumFrequency: { type: Type.STRING, enum: ['monthly', 'quarterly', 'yearly', 'unknown'] },
    startDate: str('YYYY-MM-DD or empty'),
    renewalDate: str('YYYY-MM-DD or empty'),
    deductibleIndividual: num(),
    deductibleFamily: num(),
    outOfPocketMaxIndividual: num(),
    outOfPocketMaxFamily: num(),
    copayPrimaryCare: num(),
    copaySpecialist: num(),
    copayEmergency: num(),
    coinsurancePercent: num('Patient share after deductible, e.g. 20.'),
    networkType: str('HMO / PPO / EPO / POS / not applicable.'),
    exclusions: strList('Key exclusions and restrictions.'),
    waitingPeriods: strList(),
    beneficiaryName: str('Beneficiary / nominee if shown.'),
    summary: str('Plain-language summary of what this policy covers and the key cost-sharing numbers.'),
    confidence: num(),
    warnings: strList(),
  },
  required: ['insurerName', 'policyType', 'currency', 'summary', 'confidence', 'warnings', 'premiumFrequency'],
};

export const recordSchema: Schema = {
  type: Type.OBJECT,
  properties: {
    recordType: { type: Type.STRING, enum: ['lab', 'imaging', 'prescription', 'discharge', 'vaccination', 'consultation', 'other'] },
    providerName: str('Clinic / hospital / doctor.'),
    date: str('YYYY-MM-DD or empty'),
    title: str('Short descriptive title, e.g. "Complete Blood Count — 12 Mar 2026".'),
    summary: str('Patient-friendly Markdown summary. Explain what was tested/found and what it generally means. No diagnosis; recommend discussing with the treating clinician.'),
    keyValues: str('Every notable test name, value, unit and reference range — one per line; medication names/doses for a prescription; vaccine names for vaccination.'),
    labMarkers: {
      type: Type.ARRAY,
      description:
        'For lab reports only: one entry per measured marker, exactly as printed. Leave empty for other record types.',
      items: {
        type: Type.OBJECT,
        properties: {
          name: str('Marker name as printed, e.g. "LDL Cholesterol", "HbA1c".'),
          value: num('Numeric result. Omit the entry if the result is not numeric.'),
          unit: str('Unit as printed, e.g. mg/dL, %, ng/mL. Empty if none.'),
          refLow: num('Lower bound of the printed reference range, or 0 when the range is "< X".'),
          refHigh: num('Upper bound of the printed reference range, or 0 when the range is "> X" or absent.'),
          refText: str('Reference range exactly as printed, e.g. "< 100", "30 – 100", "3.5–5.1".'),
          flag: { type: Type.STRING, enum: ['low', 'normal', 'high', 'abnormal', 'unknown'], description: 'The lab\'s own flag if printed (H/L/A); otherwise derive from value vs range; "unknown" if no range.' },
        },
        required: ['name', 'value', 'unit', 'refLow', 'refHigh', 'refText', 'flag'],
      },
    },
    abnormalFindings: strList('Values flagged outside reference range, verbatim.'),
    followUps: strList('Follow-up instructions printed on the document.'),
    confidence: num(),
    warnings: strList(),
  },
  required: ['recordType', 'title', 'summary', 'keyValues', 'confidence', 'warnings'],
};

export const FINDING_TYPES = [
  'duplicate',
  'unbundling',
  'upcoding',
  'quantity',
  'not_received',
  'overpriced',
  'facility_fee',
  'balance_billing',
  'not_covered_wrongly',
  'coordination',
  'non_payable_item',
  'package_rate',
  'math_error',
  'other',
] as const;

const finding: Schema = {
  type: Type.OBJECT,
  properties: {
    id: str('Short stable id like F1, F2.'),
    type: { type: Type.STRING, enum: [...FINDING_TYPES] },
    severity: { type: Type.STRING, enum: ['low', 'medium', 'high'] },
    title: str('Short headline, e.g. "Duplicate CBC charge on 12 Mar".'),
    explanation: str('2-4 sentences: what is wrong and why it is disputable, in plain language.'),
    expenseIds: strList('Ids of the expenses/bills this finding relates to.'),
    lineDescriptions: strList('The exact line item descriptions/codes involved.'),
    amountAtIssue: num('Total billed amount of the lines involved.'),
    estimatedSavingLow: num('Conservative saving if the dispute succeeds.'),
    estimatedSavingHigh: num('Optimistic saving.'),
    benchmarkCode: str('Code compared against a benchmark, else empty.'),
    benchmarkReferencePrice: num('Reference price used (0 if none).'),
    benchmarkRatio: num('billed unit price / reference price (0 if none).'),
    recommendedAction: str('One concrete step: what to request/dispute and from whom.'),
    disputeParagraph: str('A ready-to-paste paragraph for a dispute letter, firm and factual, citing the amounts.'),
    confidence: num('0-1'),
  },
  required: ['id', 'type', 'severity', 'title', 'explanation', 'amountAtIssue', 'estimatedSavingLow', 'estimatedSavingHigh', 'recommendedAction', 'disputeParagraph', 'confidence', 'expenseIds', 'lineDescriptions'],
};

export const auditSchema: Schema = {
  type: Type.OBJECT,
  properties: {
    summary: str('3-5 sentence plain-language verdict on this bill set.'),
    overallRisk: { type: Type.STRING, enum: ['low', 'medium', 'high'], description: 'How likely the bills contain recoverable errors.' },
    findings: { type: Type.ARRAY, items: finding },
    totalSavingLow: num(),
    totalSavingHigh: num(),
    itemizedBillMissing: bool('True if the audit was limited because no itemized bill was provided.'),
    charityCareLikely: bool('True if financial assistance / charity care is worth applying for.'),
    charityCareNote: str('Why, and what to ask the provider; empty if not applicable.'),
    nextSteps: strList('Ordered, concrete next steps for the patient.'),
    questionsForUser: strList('Facts that would sharpen the audit (e.g. "Was the CT scan actually performed?").'),
  },
  required: ['summary', 'overallRisk', 'findings', 'totalSavingLow', 'totalSavingHigh', 'itemizedBillMissing', 'charityCareLikely', 'nextSteps', 'questionsForUser'],
};

export const denialExplanationSchema: Schema = {
  type: Type.OBJECT,
  properties: {
    plainSummary: str('What happened, in 3-4 plain sentences.'),
    whyDenied: str('The insurer’s reasoning restated, and what it would take to overcome it.'),
    isDisputable: bool(),
    strength: { type: Type.STRING, enum: ['weak', 'moderate', 'strong'] },
    arguments: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: { title: str(), detail: str('How to argue it, what to cite (policy terms, medical necessity, rights).') },
        required: ['title', 'detail'],
      },
    },
    evidenceToGather: strList('Documents to collect: records, letters of medical necessity, policy sections, EOBs…'),
    steps: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          stage: str(),
          action: str(),
          deadline: str('Human readable.'),
          daysFromDenial: num('Days after the denial date by which to act; 0 if not applicable.'),
        },
        required: ['stage', 'action', 'deadline', 'daysFromDenial'],
      },
    },
    successEstimate: str('Honest, hedged estimate of the odds and what drives them.'),
    questionsForUser: strList(),
  },
  required: ['plainSummary', 'whyDenied', 'isDisputable', 'strength', 'arguments', 'evidenceToGather', 'steps', 'successEstimate', 'questionsForUser'],
};

export const letterSchema: Schema = {
  type: Type.OBJECT,
  properties: {
    subject: str('Subject / Re: line.'),
    recipientBlock: str('Who it is addressed to (department, insurer/provider name, address if known).'),
    body: str('The complete letter body in plain text with paragraphs separated by blank lines. No markdown. Placeholders in [SQUARE BRACKETS] only where a fact is genuinely unknown.'),
    checklist: strList('Documents to enclose.'),
    sendingTips: strList('How/where to send, what to keep, and the follow-up date.'),
    deadlineNote: str('The relevant deadline for this letter, if any.'),
  },
  required: ['subject', 'recipientBlock', 'body', 'checklist', 'sendingTips', 'deadlineNote'],
};
