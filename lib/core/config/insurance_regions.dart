import 'package:intl/intl.dart';

/// One stage of a region's appeal path, with the deadline the app uses to
/// create reminders (mirrors functions/src/regions.ts).
class AppealStage {
  final String stage;
  final String deadline;
  final int daysFromDenial; // 0 = no automatic reminder
  final String notes;
  const AppealStage({
    required this.stage,
    required this.deadline,
    this.daysFromDenial = 0,
    this.notes = '',
  });
}

/// A supported country/region for insurance handling. Drives currency display
/// and the regulator / ombudsman / legal-escalation context injected into the
/// AI prompts so claim advice and appeals are correct per country.
class InsuranceRegion {
  /// ISO-ish country code used for storage (`US`, `GB`, `CA`, `AU`, `IN`, `EU`).
  final String code;
  final String name;
  final String currencyCode; // ISO 4217, e.g. USD
  final String currencySymbol;
  final String locale; // for NumberFormat / date formatting
  /// What a policy's named recipient is called here ("Beneficiary" vs "Nominee").
  final String beneficiaryTerm;

  /// The market conduct regulator (e.g. "FCA").
  final String regulator;

  /// The free, independent dispute body (e.g. "Financial Ombudsman Service").
  final String ombudsman;

  /// Ordered, country-correct escalation path for a denied claim.
  final List<String> escalationSteps;

  /// Key consumer-protection laws / rights the policyholder can rely on.
  final String keyRights;

  /// Country-correct appeal stages with deadlines counted from the denial.
  final List<AppealStage> appealStages;

  /// Short description of how bills / private insurance work here.
  final String billingNote;

  const InsuranceRegion({
    required this.code,
    required this.name,
    required this.currencyCode,
    required this.currencySymbol,
    required this.locale,
    this.beneficiaryTerm = 'Beneficiary',
    this.regulator = 'the national insurance regulator',
    this.ombudsman = 'the financial/insurance ombudsman',
    this.escalationSteps = const [],
    this.keyRights = '',
    this.appealStages = const [],
    this.billingNote = '',
  });

  String get flag => _flagFor(code);
}

/// Supported regions. Order is the display order in pickers.
const List<InsuranceRegion> kInsuranceRegions = [
  InsuranceRegion(
    code: 'US',
    name: 'United States',
    currencyCode: 'USD',
    currencySymbol: r'$',
    locale: 'en_US',
    beneficiaryTerm: 'Beneficiary',
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
        'ACA internal & external appeal rights, the No Surprises Act, ERISA (employer plans), and state prompt-payment laws.',
    appealStages: [
      AppealStage(stage: 'Internal appeal (1st level)', deadline: '180 days from the denial notice', daysFromDenial: 180,
          notes: 'Decision within 30 days (pre-service) / 60 days (post-service); 72 h if urgent.'),
      AppealStage(stage: 'Internal appeal (2nd level)', deadline: 'Usually 60 days after the 1st-level decision', daysFromDenial: 240),
      AppealStage(stage: 'External review (IRO)', deadline: '4 months after the final internal denial', daysFromDenial: 300,
          notes: 'Independent and binding on the insurer. Free.'),
      AppealStage(stage: 'State Department of Insurance complaint', deadline: 'Any time'),
    ],
    billingNote:
        'Itemized bills use CPT/HCPCS codes; the insurer’s EOB shows billed vs allowed vs paid. Medicare rates are the fair-price reference; the No Surprises Act limits balance billing.',
  ),
  InsuranceRegion(
    code: 'GB',
    name: 'United Kingdom',
    currencyCode: 'GBP',
    currencySymbol: '£',
    locale: 'en_GB',
    beneficiaryTerm: 'Beneficiary',
    regulator: 'the Financial Conduct Authority (FCA)',
    ombudsman: 'the Financial Ombudsman Service (FOS)',
    escalationSteps: [
      "Make a formal written complaint to the insurer and obtain their final response (deadlock) letter.",
      'Escalate to the Financial Ombudsman Service (FOS) within 6 months of the final response — it is free to you.',
      "A FOS decision is binding on the insurer if you accept it.",
    ],
    keyRights:
        "the FCA's ICOBS rules, the Consumer Rights Act 2015, and free, binding FOS dispute resolution.",
    appealStages: [
      AppealStage(stage: 'Formal complaint to the insurer', deadline: 'Insurer must give a final response within 8 weeks', daysFromDenial: 30),
      AppealStage(stage: 'Financial Ombudsman Service', deadline: '6 months from the final response letter', daysFromDenial: 236,
          notes: 'Free; binding on the insurer if you accept.'),
    ],
    billingNote:
        'Disputes mostly concern private medical insurance (pre-authorisation, exclusions, consultant fee shortfalls) and private hospital invoices.',
  ),
  InsuranceRegion(
    code: 'CA',
    name: 'Canada',
    currencyCode: 'CAD',
    currencySymbol: r'$',
    locale: 'en_CA',
    beneficiaryTerm: 'Beneficiary',
    regulator: 'your provincial insurance regulator',
    ombudsman: 'the OmbudService for Life & Health Insurance (OLHI)',
    escalationSteps: [
      "Complete the insurer's internal complaint process and obtain a final position letter.",
      'Escalate to the OmbudService for Life & Health Insurance (OLHI) — free and independent.',
      'Complain to your provincial insurance regulator / FCAC.',
    ],
    keyRights:
        'provincial Insurance Acts, your access rights under PIPEDA, and OLHI recommendations.',
    appealStages: [
      AppealStage(stage: 'Insurer internal appeal', deadline: 'Commonly 30–90 days — check the letter', daysFromDenial: 60),
      AppealStage(stage: 'OLHI complaint', deadline: 'After the final position letter, within 1 year', daysFromDenial: 180),
    ],
    billingNote:
        'Provincial plans cover hospital and physician care; disputes involve extended-health benefits (drugs, dental, paramedical) and travel insurance.',
  ),
  InsuranceRegion(
    code: 'AU',
    name: 'Australia',
    currencyCode: 'AUD',
    currencySymbol: r'$',
    locale: 'en_AU',
    beneficiaryTerm: 'Beneficiary',
    regulator: 'the Australian Prudential Regulation Authority (APRA)',
    ombudsman: 'the Australian Financial Complaints Authority (AFCA)',
    escalationSteps: [
      "Use the insurer's Internal Dispute Resolution (IDR) process — they must respond within 30 days.",
      'Escalate to the Australian Financial Complaints Authority (AFCA) — free, and its decisions are binding.',
      'For private health insurance, you may also use the Private Health Insurance Ombudsman.',
    ],
    keyRights:
        'the Insurance Contracts Act 1984, the duty of utmost good faith, and binding AFCA decisions.',
    appealStages: [
      AppealStage(stage: 'Internal Dispute Resolution', deadline: 'Insurer must respond within 30 days', daysFromDenial: 30),
      AppealStage(stage: 'AFCA / Private Health Insurance Ombudsman', deadline: 'Within 2 years of the IDR response', daysFromDenial: 120,
          notes: 'Free; AFCA decisions bind the insurer.'),
    ],
    billingNote:
        'Medicare covers public care and part of the MBS fee; gap fees and product-tier exclusions drive most private-cover disputes.',
  ),
  InsuranceRegion(
    code: 'EU',
    name: 'Europe (Eurozone)',
    currencyCode: 'EUR',
    currencySymbol: '€',
    locale: 'en_IE',
    beneficiaryTerm: 'Beneficiary',
    regulator: 'your national insurance regulator (under EIOPA)',
    ombudsman: 'your national insurance ombudsman (FIN-NET for cross-border)',
    escalationSteps: [
      "Submit a written complaint to the insurer's complaints department.",
      'Escalate to your national insurance ombudsman or ADR body.',
      'For cross-border disputes use the FIN-NET network; the regulator operates under EIOPA oversight.',
    ],
    keyRights:
        'the Insurance Distribution Directive, GDPR (access to your records), and national consumer-protection law.',
    appealStages: [
      AppealStage(stage: 'Written complaint to the insurer', deadline: 'As soon as possible — reply within 15 working days to 2 months', daysFromDenial: 30),
      AppealStage(stage: 'National ombudsman / ADR body', deadline: 'After the final answer, typically within 1 year', daysFromDenial: 180),
    ],
    billingNote:
        'Statutory insurance covers most care; disputes concern supplementary/private cover, tariffs and cross-border reimbursement.',
  ),
  InsuranceRegion(
    code: 'IN',
    name: 'India',
    currencyCode: 'INR',
    currencySymbol: '₹',
    locale: 'en_IN',
    beneficiaryTerm: 'Nominee',
    regulator:
        'the Insurance Regulatory and Development Authority of India (IRDAI)',
    ombudsman: 'the Insurance Ombudsman',
    escalationSteps: [
      "File a written grievance with the insurer's Grievance Redressal Officer.",
      "Escalate through IRDAI's Bima Bharosa grievance portal.",
      'Approach the Insurance Ombudsman (free; for claims up to the prescribed limit).',
      'File before the Consumer Forum / NCDRC if still unresolved.',
    ],
    keyRights:
        "the IRDAI (Protection of Policyholders' Interests) Regulations and the Consumer Protection Act, 2019.",
    appealStages: [
      AppealStage(stage: 'Grievance Redressal Officer', deadline: 'Insurer must resolve within 15 days', daysFromDenial: 15),
      AppealStage(stage: 'IRDAI Bima Bharosa portal', deadline: 'If unresolved after 15 days', daysFromDenial: 30),
      AppealStage(stage: 'Insurance Ombudsman', deadline: 'Within 1 year of the rejection', daysFromDenial: 365,
          notes: 'Free; claims up to ₹50 lakh.'),
    ],
    billingNote:
        'Cashless claims are pre-authorised by the TPA; deductions cite room-rent capping, non-payable consumables, sub-limits and waiting periods.',
  ),
];

/// Fallback for unknown/empty codes. Intentionally India: every record saved
/// before the global update has an empty country/currency and was implicitly
/// in ₹, so legacy data must keep rendering as ₹ rather than flipping to $.
/// New cases/policies always store an explicit country, so this only affects
/// legacy data and the picker's initial selection.
final InsuranceRegion kDefaultRegion =
    kInsuranceRegions.firstWhere((r) => r.code == 'IN');

/// Look up a region by country code; falls back to [kDefaultRegion].
InsuranceRegion regionByCode(String? code) {
  if (code == null || code.isEmpty) return kDefaultRegion;
  for (final r in kInsuranceRegions) {
    if (r.code == code) return r;
  }
  return kDefaultRegion;
}

/// Look up a region by currency code (used when only currency was stored).
InsuranceRegion regionByCurrency(String? currencyCode) {
  if (currencyCode == null || currencyCode.isEmpty) return kDefaultRegion;
  for (final r in kInsuranceRegions) {
    if (r.currencyCode == currencyCode) return r;
  }
  return kDefaultRegion;
}

/// Converts a 2-letter region code into its emoji flag (regional indicators).
/// `EU` maps to the European Union flag.
String _flagFor(String code) {
  if (code == 'EU') return '🇪🇺';
  if (code.length != 2) return '🏳️';
  const base = 0x1F1E6; // 'A'
  final upper = code.toUpperCase();
  return String.fromCharCodes([
    base + (upper.codeUnitAt(0) - 0x41),
    base + (upper.codeUnitAt(1) - 0x41),
  ]);
}

/// Formats [amount] in the given [currencyCode] using locale-aware grouping.
/// Whole numbers drop the decimals (e.g. `$1,250`); fractional values keep two
/// (e.g. `$1,250.50`).
String formatMoney(double amount, String currencyCode) {
  final region = regionByCurrency(currencyCode);
  final hasFraction = amount != amount.roundToDouble();
  final fmt = NumberFormat.currency(
    locale: region.locale,
    symbol: region.currencySymbol,
    decimalDigits: hasFraction ? 2 : 0,
  );
  return fmt.format(amount);
}
