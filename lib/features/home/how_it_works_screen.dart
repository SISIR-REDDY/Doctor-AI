import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Divider;

import 'package:provider/provider.dart';

import '../../core/config/insurance_regions.dart';
import '../../core/providers/health_data_provider.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';
import '../../theme/motion.dart';
import '../scan/document_scan_screen.dart';

/// Exactly what happens to a document after you scan it — for the two
/// engines that carry the app: bills & claims, and lab reports.
///
/// Everything listed here is what the code actually does (see
/// functions/src/tasks/audit.ts and the record schema). If a step is added
/// or removed there, update it here; this screen is a promise.
class HowItWorksScreen extends StatefulWidget {
  final int initialTab;
  const HowItWorksScreen({super.key, this.initialTab = 0});

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen> {
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    Analytics.screen('how_it_works');
  }

  @override
  Widget build(BuildContext context) {
    return LargeTitleScaffold(
      title: 'How it works',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _tab,
              onValueChanged: (v) => setState(() => _tab = v ?? 0),
              children: const {
                0: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Bills')),
                1: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Reports')),
                2: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Your country')),
              },
            ),
          ),
        ),
        switch (_tab) {
          0 => const _ClaimsPipeline(),
          1 => const _ReportsPipeline(),
          _ => const _CountryGuide(),
        },
        const SizedBox(height: 120),
      ],
    );
  }
}

// ── Bills & claims ────────────────────────────────────────────────────────────

class _ClaimsPipeline extends StatelessWidget {
  const _ClaimsPipeline();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Intro(
          'From a photo of a bill to money back — every step, and what Clinix checks at each one.',
        ),
        _Step(
          n: 1,
          icon: CupertinoIcons.camera_viewfinder,
          color: AppTheme.primaryColor,
          title: 'Scan',
          body:
              'Photograph or import a bill, an insurer statement (EOB), a denial letter or your policy. Clinix works out which it is.',
          detail: const ['Photo, PDF or multiple pages', 'Bill · EOB · Denial · Policy'],
        ),
        _Step(
          n: 2,
          icon: CupertinoIcons.list_number,
          color: AppTheme.infoColor,
          title: 'Read every line',
          body:
              'Each charge is extracted as a structured line: the code (CPT / HCPCS / ICD), description, date of service, quantity, unit price and amount.',
          detail: const ['Codes and modifiers', 'Quantities and dates', 'Totals cross-checked'],
        ),
        _Step(
          n: 3,
          icon: CupertinoIcons.doc_text_search,
          color: AppTheme.warningColor,
          title: 'Audit',
          body:
              'Deterministic rules run first, then an AI review explains what they found. Rules fire only on evidence in the document itself.',
          detail: const [
            'Duplicate — the same code, same day, billed twice',
            'Quantity — a visit code billed more than once per day',
            'Overpriced — a charge ≥ 3× the Medicare reference rate',
            'Math — line items that don’t add up to the total',
          ],
        ),
        const _SourceCard(
          title: 'Reference prices',
          body:
              'Medicare fee schedules — the Physician Fee Schedule, Clinical Lab Fee Schedule and Outpatient PPS. Public, updated by CMS. Labelled approximate until the full import runs.',
          icon: CupertinoIcons.chart_bar_square_fill,
        ),
        _Step(
          n: 4,
          icon: CupertinoIcons.shield_lefthalf_fill,
          color: AppTheme.secondaryColor,
          title: 'Match your coverage',
          body:
              'If you have a policy on file, the EOB is read against it: deductible, out-of-pocket max, copays, network status — so “patient owes” can be questioned, not just accepted.',
          detail: const ['Deductible & OOP tracker', 'In / out of network', 'Denial reason category'],
        ),
        _Step(
          n: 5,
          icon: CupertinoIcons.pencil_outline,
          color: AppTheme.successColor,
          title: 'Draft the letter',
          body:
              'A dispute (to the provider) or an appeal (to the insurer), citing the findings, your policy terms and your rights in your country. You review it, edit it, and send it yourself.',
          detail: const ['Itemized-bill request', 'Billing dispute', 'Internal & external appeal'],
        ),
        _Step(
          n: 6,
          icon: CupertinoIcons.calendar_badge_plus,
          color: AppTheme.dangerColor,
          title: 'Track the deadline',
          body:
              'Appeal windows are read from the letter, or set from your region’s rules. Reminders fire 7 days, 1 day and the day before it closes.',
          detail: const ['US: 180 days internal appeal (ACA plans)', 'UK: 8 weeks → Financial Ombudsman', 'AU: Commonwealth Ombudsman'],
        ),
        _Step(
          n: 7,
          icon: CupertinoIcons.money_dollar_circle_fill,
          color: AppTheme.successColor,
          title: 'Record the outcome',
          body:
              'Mark what was reduced, waived or overturned. Recovered money is counted on Home; findings that didn’t hold are closed.',
          last: true,
        ),
        const _Boundary(
          'Clinix prepares and explains. It never contacts a provider or insurer, never negotiates, and never takes a share of what you recover.',
        ),
        _Cta(label: 'Scan a bill', onTap: () => DocumentScanScreen.open(context, trigger: 'how_it_works_claims')),
      ],
    );
  }
}

// ── Lab reports ───────────────────────────────────────────────────────────────

class _ReportsPipeline extends StatelessWidget {
  const _ReportsPipeline();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Intro(
          'From a lab printout to something you can actually read — and compare with last time.',
        ),
        _Step(
          n: 1,
          icon: CupertinoIcons.camera_viewfinder,
          color: AppTheme.primaryColor,
          title: 'Scan',
          body: 'A blood panel, imaging report, discharge summary, prescription or vaccination record.',
          detail: const ['Any lab or clinic format', 'Multi-page reports'],
        ),
        _Step(
          n: 2,
          icon: CupertinoIcons.lab_flask_solid,
          color: AppTheme.infoColor,
          title: 'Extract each marker',
          body:
              'Every measured value becomes a structured entry: name, result, unit and the reference range exactly as the laboratory printed it.',
          detail: const ['Name · value · unit', 'Lab’s own reference range', 'Lab’s own H / L flag'],
        ),
        _Step(
          n: 3,
          icon: CupertinoIcons.slider_horizontal_below_rectangle,
          color: AppTheme.warningColor,
          title: 'Place it on the range',
          body:
              'The lab’s flag wins. Without one, the value is judged against the printed range. Without a range, it is shown plainly — Clinix never invents a threshold.',
          detail: const ['Green · in range', 'Amber · low', 'Red · high or abnormal', 'Grey · no range printed'],
        ),
        _Step(
          n: 4,
          icon: CupertinoIcons.arrow_up_right_circle_fill,
          color: AppTheme.secondaryColor,
          title: 'Compare with last time',
          body:
              'The same marker is matched across your earlier reports, so each result shows the change: “+17 since March (was 131)”.',
          detail: const ['Matches “LDL-C” to “LDL cholesterol”', 'Most recent earlier reading', 'Works across labs'],
        ),
        _Step(
          n: 5,
          icon: CupertinoIcons.text_bubble_fill,
          color: AppTheme.successColor,
          title: 'Explain in plain English',
          body:
              'What was tested, what is outside range, and what is generally worth raising with your clinician. General information — never a diagnosis.',
          detail: const ['Abnormal markers first', 'Questions to ask', 'Export as PDF for your doctor'],
        ),
        _Step(
          n: 6,
          icon: CupertinoIcons.waveform,
          color: AppTheme.oncologyColor,
          title: 'Ask the assistant',
          body:
              'The assistant reads your lab history and medications before it answers, and says which report it is citing.',
          last: true,
        ),
        const _Boundary(
          'Clinix explains results; it does not diagnose or treat. In an emergency, call your local emergency number.',
        ),
        _Cta(label: 'Scan a report', onTap: () => DocumentScanScreen.open(context, trigger: 'how_it_works_reports')),
      ],
    );
  }
}

// ── Your country ──────────────────────────────────────────────────────────────

/// How a denied claim is escalated where the user lives: the documents, the
/// regulator, the ombudsman, the appeal stages with their deadlines, and the
/// rights the letters cite. All of it comes from the region engine that the
/// audit, deadlines and letters already run on — this just shows it.
class _CountryGuide extends StatefulWidget {
  const _CountryGuide();

  @override
  State<_CountryGuide> createState() => _CountryGuideState();
}

class _CountryGuideState extends State<_CountryGuide> {
  String? _code;

  @override
  Widget build(BuildContext context) {
    final profileCountry = context.watch<HealthDataProvider>().profile?.country;
    final region = regionByCode(_code ?? profileCountry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Intro(
          'Insurance disputes follow a different path in every country. Clinix sets deadlines, reminders and letter wording from the rules below.',
        ),
        // Country chooser — a horizontal row of flag chips.
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final r in kInsuranceRegions) ...[
                _CountryChip(
                  region: r,
                  selected: r.code == region.code,
                  onTap: () => setState(() => _code = r.code),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _RegionFacts(region: region),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Appeal path in ${region.name}',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4,
                  color: AppTheme.textPrimary)),
        ),
        for (var i = 0; i < region.appealStages.length; i++)
          _Step(
            n: i + 1,
            icon: i == region.appealStages.length - 1
                ? CupertinoIcons.checkmark_seal_fill
                : CupertinoIcons.arrow_right_circle_fill,
            color: i == 0 ? AppTheme.primaryColor : AppTheme.secondaryColor,
            title: region.appealStages[i].stage,
            body: region.appealStages[i].deadline,
            detail: [
              if (region.appealStages[i].daysFromDenial > 0)
                'Clinix reminds you ${region.appealStages[i].daysFromDenial} days after the denial',
              if (region.appealStages[i].notes.isNotEmpty) region.appealStages[i].notes,
            ],
            last: i == region.appealStages.length - 1,
          ),
        if (region.keyRights.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SourceCard(
            title: 'Rights the letters cite',
            body: region.keyRights,
            icon: CupertinoIcons.doc_on_clipboard_fill,
          ),
        ],
        _Boundary(
          'Escalating to ${region.ombudsman} is free. Clinix prepares the file; you submit it.',
        ),
        _Cta(label: 'Scan a denial letter', onTap: () => DocumentScanScreen.open(context, trigger: 'how_it_works_country')),
      ],
    );
  }
}

class _CountryChip extends StatelessWidget {
  final InsuranceRegion region;
  final bool selected;
  final VoidCallback onTap;
  const _CountryChip({required this.region, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DSPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(region.flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 7),
            Text(region.name,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }
}

/// Four facts that differ per country, as an iOS grouped list.
class _RegionFacts extends StatelessWidget {
  final InsuranceRegion region;
  const _RegionFacts({required this.region});

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[
      (CupertinoIcons.doc_text_fill, 'What you receive', region.billingNote),
      (CupertinoIcons.building_2_fill, 'Regulator', region.regulator),
      (CupertinoIcons.person_2_fill, 'Free dispute body', region.ombudsman),
      (CupertinoIcons.money_dollar_circle_fill, 'Currency', '${region.currencyCode} (${region.currencySymbol})'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InsetCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 54, color: AppTheme.dividerColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(rows[i].$1, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rows[i].$2,
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(rows[i].$3,
                              style: TextStyle(fontSize: 14, height: 1.35, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _Intro extends StatelessWidget {
  final String text;
  const _Intro(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Text(text,
            style: TextStyle(fontSize: 15.5, height: 1.4, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
      );
}

/// One pipeline stage on a vertical rail.
class _Step extends StatelessWidget {
  final int n;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final List<String> detail;
  final bool last;

  const _Step({
    required this.n,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.detail = const [],
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  IconBadge(icon, color: color, size: 40),
                  if (!last)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: AppTheme.dividerColor,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Text('$n. $title',
                          style: TextStyle(
                              fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -0.3,
                              color: AppTheme.textPrimary)),
                    ),
                    const SizedBox(height: 4),
                    Text(body,
                        style: TextStyle(fontSize: 14, height: 1.4, color: AppTheme.textSecondary)),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceMuted,
                          borderRadius: DS.squircle(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final d in detail)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.5),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Icon(CupertinoIcons.checkmark_alt, size: 13, color: color),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(d,
                                          style: TextStyle(
                                              fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w600,
                                              color: AppTheme.textPrimary)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  const _SourceCard({required this.title, required this.body, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(74, 0, 20, 22),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: AppTheme.isDark ? 0.16 : 0.09),
          borderRadius: DS.squircle(12),
          border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3), width: 0.8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppTheme.warningColor),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(body, style: TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Boundary extends StatelessWidget {
  final String text;
  const _Boundary(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
        child: InsetCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.hand_raised_fill, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
              ),
            ],
          ),
        ),
      );
}

class _Cta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Cta({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: HeroButton(label: label, icon: CupertinoIcons.camera_viewfinder, onTap: onTap),
      );
}
