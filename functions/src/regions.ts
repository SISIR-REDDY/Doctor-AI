/**
 * Server-side region knowledge injected into every prompt so bill audits,
 * denial explanations and letters are correct for the user's country.
 *
 * This is the source of truth for prompt context; the Flutter app keeps a
 * lighter copy for display (lib/core/config/insurance_regions.dart).
 */

export type RegionCode = 'US' | 'GB' | 'CA' | 'AU' | 'EU' | 'IN';

export interface AppealStage {
  /** e.g. "Internal appeal (1st level)" */
  stage: string;
  /** Human-readable deadline — quoted verbatim in letters/UI. */
  deadline: string;
  /** Days from the denial date the user should act by (for auto-reminders). */
  daysFromDenial?: number;
  notes?: string;
}

export interface Region {
  code: RegionCode;
  name: string;
  currencyCode: string;
  currencySymbol: string;
  regulator: string;
  ombudsman: string;
  escalationSteps: string[];
  keyRights: string;
  /** How medical billing / private insurance actually works here. */
  billingContext: string;
  /** Vocabulary used on documents so the extractor recognises them. */
  documentVocabulary: string;
  /** Coding systems that may appear on itemised bills. */
  codingSystems: string;
  /** Country-correct appeal stages with deadlines. */
  appealStages: AppealStage[];
  /** Which fair-price benchmark dataset (if any) applies. */
  benchmarkSource: 'CMS_PFS' | 'AU_MBS' | null;
  /** Common, disputable billing problems in this market. */
  commonBillingIssues: string[];
}

export const REGIONS: Record<RegionCode, Region> = {
  US: {
    code: 'US',
    name: 'United States',
    currencyCode: 'USD',
    currencySymbol: '$',
    regulator: 'your state Department of Insurance (DOI)',
    ombudsman: 'an Independent Review Organization (external review)',
    escalationSteps: [
      'File a written internal appeal with the insurer; request the full claim file and the specific denial rationale.',
      'Request an independent external review (IRO) — guaranteed for most plans under the Affordable Care Act.',
      'File a complaint with your state Department of Insurance.',
      'If this is an employer/ERISA plan, follow ERISA appeal rights and consider the U.S. Department of Labor.',
      'For surprise or balance bills, invoke the federal No Surprises Act.',
    ],
    keyRights:
      'ACA internal & external appeal rights (45 CFR 147.136), the No Surprises Act, ERISA §503 (employer plans), state prompt-payment laws, and the right to an itemized bill and your medical records under HIPAA.',
    billingContext:
      'Providers bill line items coded with CPT/HCPCS (procedures) and ICD-10-CM (diagnoses). The insurer sends an Explanation of Benefits (EOB) showing billed amount, allowed amount, plan paid, and patient responsibility (deductible, copay, coinsurance). Patients may only be balance-billed by out-of-network providers, and the No Surprises Act bans balance billing for emergency care and for out-of-network care at in-network facilities. Nonprofit hospitals must offer financial assistance (charity care) under IRS 501(r). Medicare fee-schedule rates are the standard fair-price reference; commercial prices of 2-4x Medicare are typical and anything above ~3x for the same code is worth disputing.',
    documentVocabulary:
      'Itemized statement, UB-04, CMS-1500, Explanation of Benefits (EOB), Summary of Benefits and Coverage (SBC), Adverse Benefit Determination, Notice of Denial, prior authorization, medical necessity, allowed amount, patient responsibility, deductible, out-of-pocket maximum.',
    codingSystems: 'CPT, HCPCS Level II, ICD-10-CM, revenue codes (UB-04), NDC for drugs, modifiers (25, 59, 26, TC).',
    appealStages: [
      {
        stage: 'Internal appeal (1st level)',
        deadline: '180 days from the date of the denial notice (ACA minimum)',
        daysFromDenial: 180,
        notes: 'Insurer must decide within 30 days (pre-service) or 60 days (post-service); urgent care 72 hours.',
      },
      {
        stage: 'Internal appeal (2nd level, if the plan has one)',
        deadline: 'Usually 60 days from the 1st-level decision — check the denial letter',
        daysFromDenial: 240,
      },
      {
        stage: 'External review (Independent Review Organization)',
        deadline: '4 months after the final internal denial',
        daysFromDenial: 300,
        notes: 'Binding on the insurer. Free. Available for medical-necessity, experimental, and rescission denials.',
      },
      {
        stage: 'State DOI complaint',
        deadline: 'Any time; best filed alongside the external review',
      },
    ],
    benchmarkSource: 'CMS_PFS',
    commonBillingIssues: [
      'Duplicate charges for the same code and date of service',
      'Unbundling — billing component codes separately when a bundled code applies (NCCI edits)',
      'Upcoding — e.g. 99215 billed for a brief visit',
      'Charges for services, drugs or supplies not received',
      'Quantity errors (units of a drug or supply)',
      'Facility fees added to a simple office visit',
      'Balance billing that violates the No Surprises Act',
      'Charges exceeding roughly 3x the Medicare rate for the same code',
      'Emergency room level (99285) inconsistent with a minor complaint',
      'Charity care not screened for at a nonprofit hospital',
    ],
  },
  GB: {
    code: 'GB',
    name: 'United Kingdom',
    currencyCode: 'GBP',
    currencySymbol: '£',
    regulator: 'the Financial Conduct Authority (FCA)',
    ombudsman: 'the Financial Ombudsman Service (FOS)',
    escalationSteps: [
      'Make a formal written complaint to the insurer and obtain their final response (deadlock) letter.',
      'Escalate to the Financial Ombudsman Service (FOS) within 6 months of the final response — it is free to you.',
      'A FOS decision is binding on the insurer if you accept it.',
    ],
    keyRights:
      "the FCA's ICOBS rules (fair claims handling, ICOBS 8), the Consumer Duty, the Consumer Rights Act 2015, the Insurance Act 2015 (fair presentation), and free, binding FOS dispute resolution.",
    billingContext:
      'NHS care is free at the point of use; disputes arise with private medical insurance (PMI — Bupa, AXA Health, Aviva, Vitality), private hospital invoices (self-pay), dental plans, and travel insurance. PMI usually requires pre-authorisation; insurers pay consultants up to fee-schedule limits and shortfalls are billed to the patient. Common denial grounds: pre-existing conditions, moratorium underwriting, chronic-condition exclusions, out-of-list consultants/hospitals, and lack of GP referral. Private hospital invoices should be itemised; self-pay packages should match the quoted price.',
    documentVocabulary:
      'Pre-authorisation, benefit limit, excess, consultant fee shortfall, moratorium, chronic condition exclusion, final response letter, Guide to Private Medical Insurance.',
    codingSystems: 'OPCS-4 procedure codes, ICD-10, CCSD schedule codes (private practice), consultant fee schedules.',
    appealStages: [
      {
        stage: 'Formal complaint to the insurer',
        deadline: 'As soon as possible; insurer must issue a final response within 8 weeks',
        daysFromDenial: 30,
      },
      {
        stage: 'Financial Ombudsman Service',
        deadline: '6 months from the insurer’s final response letter',
        daysFromDenial: 236,
        notes: 'Free; decisions are binding on the insurer if you accept.',
      },
    ],
    benchmarkSource: null,
    commonBillingIssues: [
      'Consultant fee shortfalls not disclosed before treatment',
      'Charges for items covered under a self-pay package price',
      'Duplicate consumables or theatre time',
      'Denial citing a pre-existing condition without evidence',
      'Denial for lack of pre-authorisation when an emergency applied',
    ],
  },
  CA: {
    code: 'CA',
    name: 'Canada',
    currencyCode: 'CAD',
    currencySymbol: '$',
    regulator: 'your provincial insurance regulator (e.g. FSRA in Ontario, AMF in Québec, BCFSA in BC)',
    ombudsman: 'the OmbudService for Life & Health Insurance (OLHI)',
    escalationSteps: [
      "Complete the insurer's internal complaint process and obtain a final position letter.",
      'Escalate to the OmbudService for Life & Health Insurance (OLHI) — free and independent.',
      'Complain to your provincial insurance regulator / FCAC.',
    ],
    keyRights:
      'provincial Insurance Acts, your access rights under PIPEDA, the insurer’s duty of good faith, and OLHI recommendations.',
    billingContext:
      'Provincial plans cover medically necessary hospital and physician care; disputes are mostly with private extended-health benefits (Sun Life, Manulife, Canada Life, Green Shield, Blue Cross) for prescription drugs, dental, paramedical (physio, psychology), vision, and travel medical insurance. Denials cite plan maximums, reasonable-and-customary limits, pre-existing conditions (travel), coordination of benefits, and missing prior approval for drugs.',
    documentVocabulary:
      'Explanation of Benefits, claim statement, plan maximum, reasonable and customary, coordination of benefits, prior approval, drug formulary, final position letter.',
    codingSystems: 'Provincial fee codes (OHIP, MSP, RAMQ), DIN for drugs, dental procedure codes (CDA/ODA).',
    appealStages: [
      {
        stage: 'Insurer internal appeal',
        deadline: 'Check the denial letter — commonly 30 to 90 days',
        daysFromDenial: 60,
      },
      {
        stage: 'OLHI complaint',
        deadline: 'After the insurer’s final position letter (within 1 year)',
        daysFromDenial: 180,
        notes: 'Free and independent; non-binding recommendations most insurers follow.',
      },
    ],
    benchmarkSource: null,
    commonBillingIssues: [
      'Paramedical claims cut to "reasonable and customary" without disclosure',
      'Coordination-of-benefits errors between two plans',
      'Travel insurance denial citing an undisclosed pre-existing condition',
      'Dental fee-guide mismatches',
    ],
  },
  AU: {
    code: 'AU',
    name: 'Australia',
    currencyCode: 'AUD',
    currencySymbol: '$',
    regulator: 'the Australian Prudential Regulation Authority (APRA) and ASIC',
    ombudsman: 'the Australian Financial Complaints Authority (AFCA) or the Commonwealth Ombudsman (private health insurance)',
    escalationSteps: [
      "Use the insurer's Internal Dispute Resolution (IDR) process — they must respond within 30 days.",
      'Escalate to the Australian Financial Complaints Authority (AFCA) — free, and its decisions are binding.',
      'For private health insurance, you may also use the Private Health Insurance Ombudsman (Commonwealth Ombudsman).',
    ],
    keyRights:
      'the Insurance Contracts Act 1984 (duty of utmost good faith), the Private Health Insurance Act 2007, ASIC RG 271 complaint-handling rules, and binding AFCA decisions.',
    billingContext:
      'Medicare covers public hospital care and 75-100% of the MBS schedule fee for doctors; private health insurance (Medibank, Bupa, HCF, nib) covers private hospital treatment and extras. Out-of-pocket "gap" fees arise when doctors charge above the MBS fee. Denials cite waiting periods, exclusions/restrictions on the product tier (Basic/Bronze/Silver/Gold), pre-existing conditions (12-month wait), and non-participating hospitals. Informed Financial Consent must be provided before treatment.',
    documentVocabulary:
      'MBS item number, schedule fee, gap, Informed Financial Consent, waiting period, product tier, clinical category, restricted cover, benefit limit.',
    codingSystems: 'MBS item numbers, ICD-10-AM, AR-DRG, PBS codes for drugs.',
    appealStages: [
      {
        stage: 'Internal Dispute Resolution (IDR)',
        deadline: 'Lodge promptly; insurer must respond within 30 days',
        daysFromDenial: 30,
      },
      {
        stage: 'AFCA / Private Health Insurance Ombudsman',
        deadline: 'Within 2 years of the IDR final response',
        daysFromDenial: 120,
        notes: 'Free; AFCA decisions bind the insurer.',
      },
    ],
    benchmarkSource: 'AU_MBS',
    commonBillingIssues: [
      'Gap fees not disclosed under Informed Financial Consent',
      'Items billed above the MBS schedule fee without agreement',
      'Denial for a clinical category that is actually included in the tier',
      'Waiting period applied incorrectly after switching funds',
    ],
  },
  EU: {
    code: 'EU',
    name: 'Europe (EU/EEA)',
    currencyCode: 'EUR',
    currencySymbol: '€',
    regulator: 'your national insurance supervisor (under EIOPA)',
    ombudsman: 'your national insurance ombudsman or ADR body (FIN-NET for cross-border cases)',
    escalationSteps: [
      "Submit a written complaint to the insurer's complaints department.",
      'Escalate to your national insurance ombudsman or ADR body.',
      'For cross-border disputes use the FIN-NET network; the regulator operates under EIOPA oversight.',
    ],
    keyRights:
      'the Insurance Distribution Directive, GDPR (access to your records and automated-decision safeguards), national consumer-protection law, and the Cross-Border Healthcare Directive (2011/24/EU) for reimbursement of treatment in another member state.',
    billingContext:
      'Most countries have statutory health insurance; disputes concern private/supplementary insurance (e.g. PKV in Germany, mutuelles in France, private in Ireland/Netherlands), reimbursement shortfalls, cross-border treatment reimbursement, and private clinic invoices. Rules differ by country — always identify the country and apply its ombudsman scheme.',
    documentVocabulary:
      'Reimbursement statement, tariff, co-payment, supplementary insurance, prior approval (S2 form for cross-border), final complaint response.',
    codingSystems: 'National tariff codes (GOÄ in Germany, CCAM in France, DRG systems), ICD-10.',
    appealStages: [
      {
        stage: 'Written complaint to the insurer',
        deadline: 'As soon as possible — insurers generally must reply within 15 working days to 2 months depending on the country',
        daysFromDenial: 30,
      },
      {
        stage: 'National ombudsman / ADR body',
        deadline: 'After the insurer’s final answer, typically within 1 year',
        daysFromDenial: 180,
      },
    ],
    benchmarkSource: null,
    commonBillingIssues: [
      'Private clinic invoice above the national tariff without consent',
      'Reimbursement calculated on the wrong tariff',
      'Cross-border treatment reimbursement refused',
    ],
  },
  IN: {
    code: 'IN',
    name: 'India',
    currencyCode: 'INR',
    currencySymbol: '₹',
    regulator: 'the Insurance Regulatory and Development Authority of India (IRDAI)',
    ombudsman: 'the Insurance Ombudsman',
    escalationSteps: [
      "File a written grievance with the insurer's Grievance Redressal Officer.",
      "Escalate through IRDAI's Bima Bharosa grievance portal.",
      'Approach the Insurance Ombudsman (free; for claims up to the prescribed limit).',
      'File before the Consumer Forum / NCDRC if still unresolved.',
    ],
    keyRights:
      "the IRDAI (Protection of Policyholders' Interests) Regulations 2024, the IRDAI Master Circular on Health Insurance 2024 (claim decisions within 3 hours of discharge request, no claim rejection without policyholder consent for cashless), and the Consumer Protection Act, 2019.",
    billingContext:
      'Cashless claims are pre-authorised by the TPA/insurer; reimbursement claims need itemised final bills, discharge summary, and receipts. Deductions cite room-rent capping with proportionate deductions, non-payable consumables (IRDAI list), sub-limits, waiting periods (30-day initial, specified diseases, pre-existing up to 3 years), and "reasonable and customary" charges. Package rates and hospital tariffs vary widely.',
    documentVocabulary:
      'Cashless pre-authorisation, TPA, final bill, discharge summary, claim settlement letter, deduction sheet, room rent limit, co-payment, sub-limit, non-medical expenses.',
    codingSystems: 'Hospital internal tariff codes; ICD-10 on discharge summaries; IRDAI non-payable items list.',
    appealStages: [
      {
        stage: 'Grievance Redressal Officer (insurer)',
        deadline: 'Insurer must resolve within 15 days',
        daysFromDenial: 15,
      },
      {
        stage: 'IRDAI Bima Bharosa portal',
        deadline: 'If unresolved after 15 days',
        daysFromDenial: 30,
      },
      {
        stage: 'Insurance Ombudsman',
        deadline: 'Within 1 year of the insurer’s rejection / final reply',
        daysFromDenial: 365,
        notes: 'Free; for claims up to ₹50 lakh.',
      },
    ],
    benchmarkSource: null,
    commonBillingIssues: [
      'Non-payable consumables charged to the patient that the hospital should absorb under package rates',
      'Proportionate deduction applied beyond room rent-linked items',
      'Duplicate pharmacy or investigation charges',
      'Rejection citing a pre-existing disease without disclosure evidence',
    ],
  },
};

export function regionOf(code: string | undefined | null): Region {
  const key = (code || '').toUpperCase() as RegionCode;
  return REGIONS[key] ?? REGIONS.US;
}

/** Compact, prompt-ready description of a region. */
export function regionContext(region: Region): string {
  const stages = region.appealStages
    .map((s, i) => `   ${i + 1}. ${s.stage} — ${s.deadline}${s.notes ? ` (${s.notes})` : ''}`)
    .join('\n');
  const issues = region.commonBillingIssues.map((s) => `   - ${s}`).join('\n');
  return `Country: ${region.name} (${region.code}); currency ${region.currencyCode} (${region.currencySymbol}).
Regulator: ${region.regulator}.
Independent dispute body: ${region.ombudsman}.
Key rights: ${region.keyRights}
How billing & insurance work here: ${region.billingContext}
Document vocabulary: ${region.documentVocabulary}
Coding systems: ${region.codingSystems}
Appeal stages & deadlines:
${stages}
Common disputable billing issues:
${issues}
Only give guidance that is correct for ${region.name}. Never cite laws or bodies from other countries.`;
}
