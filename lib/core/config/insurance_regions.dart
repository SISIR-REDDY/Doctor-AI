import 'package:intl/intl.dart';

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
