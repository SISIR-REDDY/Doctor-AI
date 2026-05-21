import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/health_models.dart';
import '../services/chatbot_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';
import '../core/errors/app_error_handler.dart';

class LabValuesScreen extends StatefulWidget {
  const LabValuesScreen({super.key});

  @override
  State<LabValuesScreen> createState() => _LabValuesScreenState();
}

class _LabValuesScreenState extends State<LabValuesScreen> {
  final ChatbotService _chatbot = ChatbotService();
  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();

  final _labInputCtrl = TextEditingController();
  final _clinicalContextCtrl = TextEditingController();

  String _selectedPanel = 'CBC (Complete Blood Count)';
  bool _isInterpreting = false;
  List<_LabSection> _sections = [];
  String _rawResult = '';

  static const _panels = [
    'CBC (Complete Blood Count)',
    'CMP (Comprehensive Metabolic Panel)',
    'LFTs (Liver Function Tests)',
    'Thyroid Panel',
    'Lipid Panel',
    'Coagulation (PT/INR/aPTT)',
    'Arterial Blood Gas (ABG)',
    'Urinalysis',
    'Custom / Mixed',
  ];

  // Reference ranges shown as hints per panel
  static const _panelHints = {
    'CBC (Complete Blood Count)':
        'WBC: 4.0–11.0 k/µL\nRBC: 4.2–5.4 M/µL\nHgb: 12–17 g/dL\nHct: 37–52%\nMCV: 80–100 fL\nPlt: 150–400 k/µL\nNeutrophils: 50–70%\nLymphocytes: 20–40%',
    'CMP (Comprehensive Metabolic Panel)':
        'Na: 136–145 mEq/L\nK: 3.5–5.0 mEq/L\nCl: 96–106 mEq/L\nBicarb: 22–29 mEq/L\nBUN: 7–20 mg/dL\nCreatinine: 0.6–1.2 mg/dL\nGlucose: 70–100 mg/dL\nCa: 8.5–10.5 mg/dL',
    'LFTs (Liver Function Tests)':
        'ALT: 7–56 U/L\nAST: 10–40 U/L\nALP: 44–147 U/L\nGGT: 9–48 U/L\nTotal Bili: 0.1–1.2 mg/dL\nDirect Bili: 0–0.3 mg/dL\nTotal Protein: 6.3–8.2 g/dL\nAlbumin: 3.5–5.0 g/dL',
    'Thyroid Panel':
        'TSH: 0.4–4.0 mIU/L\nFree T4: 0.8–1.8 ng/dL\nFree T3: 2.3–4.1 pg/mL\nTotal T4: 5–12 µg/dL',
    'Lipid Panel':
        'Total Cholesterol: <200 mg/dL\nLDL: <100 mg/dL\nHDL: >40 (M) / >50 (F) mg/dL\nTriglycerides: <150 mg/dL\nNon-HDL: <130 mg/dL',
    'Coagulation (PT/INR/aPTT)':
        'PT: 11–13.5 sec\nINR: 0.8–1.1\naPTT: 25–35 sec\nFibrinogen: 200–400 mg/dL\nD-dimer: <0.5 µg/mL',
    'Arterial Blood Gas (ABG)':
        'pH: 7.35–7.45\nPaO2: 75–100 mmHg\nPaCO2: 35–45 mmHg\nHCO3: 22–26 mEq/L\nBE: -2 to +2\nO2 Sat: >95%',
    'Urinalysis':
        'pH: 4.5–8.0\nSG: 1.005–1.030\nProtein: negative\nGlucose: negative\nKetones: negative\nWBC: <5/hpf\nRBC: <3/hpf',
  };

  @override
  void dispose() {
    _labInputCtrl.dispose();
    _clinicalContextCtrl.dispose();
    super.dispose();
  }

  Future<void> _interpret() async {
    if (_labInputCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste or enter lab values to interpret'),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isInterpreting = true;
      _sections = [];
      _rawResult = '';
    });

    try {
      final prompt = _buildPrompt();
      final result = await _chatbot.getGeminiResponse(prompt);
      if (!mounted) return;

      final sections = _parseSections(result);
      setState(() {
        _rawResult = result;
        _sections = sections;
        _isInterpreting = false;
      });

      _autoSave(result);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isInterpreting = false);
      AppErrorHandler.showSnackBar(context, e);
    }
  }

  String _buildPrompt() {
    final context = _clinicalContextCtrl.text.trim();
    return '''
You are an experienced clinician interpreting laboratory results. Analyze the following lab values and provide a structured clinical interpretation.

PANEL TYPE: $_selectedPanel
CLINICAL CONTEXT: ${context.isEmpty ? 'Not provided' : context}

LAB VALUES:
${_labInputCtrl.text.trim()}

Provide your interpretation in this EXACT format:

SUMMARY:
[2-3 sentence clinical summary of the overall lab picture]

ABNORMAL VALUES:
[List each abnormal value as: VALUE_NAME: result (normal range) — clinical significance]

NORMAL VALUES:
[List key normal values briefly as: VALUE_NAME: result ✓]

INTERPRETATION:
[Clinical interpretation — what pattern do these labs suggest? Include physiological explanation]

ACTION ITEMS:
[Numbered list of recommended next steps: repeat tests, additional labs, imaging, referrals, medication adjustments]

DIFFERENTIAL:
[2-3 diagnoses suggested or supported by this lab pattern]

CRITICAL FLAGS:
[Any values requiring urgent/immediate action — if none, write "None"]

Be clinically precise. Use SI units where appropriate. Flag any critical values (e.g., K >6.5, Na <120, glucose <50 or >500, Hgb <7).
''';
  }

  List<_LabSection> _parseSections(String text) {
    final sections = <_LabSection>[];
    final markers = [
      ('SUMMARY:', Icons.summarize_outlined, const Color(0xFF3B82F6)),
      ('ABNORMAL VALUES:', Icons.warning_amber_rounded, const Color(0xFFEF4444)),
      ('NORMAL VALUES:', Icons.check_circle_outline, const Color(0xFF22C55E)),
      ('INTERPRETATION:', Icons.psychology_outlined, const Color(0xFF6D28D9)),
      ('ACTION ITEMS:', Icons.task_alt_outlined, const Color(0xFF0891B2)),
      ('DIFFERENTIAL:', Icons.format_list_bulleted, const Color(0xFFF59E0B)),
      ('CRITICAL FLAGS:', Icons.emergency_outlined, const Color(0xFFDC2626)),
    ];

    for (int i = 0; i < markers.length; i++) {
      final (label, icon, color) = markers[i];
      final start = text.toUpperCase().indexOf(label);
      if (start == -1) continue;

      int end = text.length;
      for (int j = i + 1; j < markers.length; j++) {
        final next = text.toUpperCase().indexOf(markers[j].$1);
        if (next != -1 && next > start && next < end) end = next;
      }

      final content = text.substring(start + label.length, end).trim();
      if (content.isNotEmpty && content.toLowerCase() != 'none') {
        sections.add(_LabSection(
          title: label.replaceAll(':', '').trim(),
          content: content,
          icon: icon,
          color: color,
        ));
      }
    }

    return sections.isEmpty
        ? [_LabSection(title: 'Result', content: text, icon: Icons.science_outlined, color: const Color(0xFF6D28D9))]
        : sections;
  }

  Future<void> _autoSave(String result) async {
    try {
      final note = ClinicalNote(
        id: const Uuid().v4(),
        patientId: 'lab_interpretation',
        title: '$_selectedPanel — ${DateFormat('MMM d, h:mm a').format(DateTime.now())}',
        content:
            'Panel: $_selectedPanel\n'
            'Context: ${_clinicalContextCtrl.text.trim()}\n\n'
            'Values:\n${_labInputCtrl.text.trim()}\n\n'
            '--- INTERPRETATION ---\n\n$result',
        diagnosis: 'Lab Values Interpretation',
        treatments: [],
        followUpItems: [],
        createdBy: _auth.currentUser?.displayName ?? 'Clinician',
        doctorId: _auth.currentUser?.uid ?? '',
      );
      await _firestore.saveClinicalReport(note);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDisclaimerBanner(),
                  const SizedBox(height: 14),
                  _buildInputCard(),
                  const SizedBox(height: 16),
                  _buildInterpretButton(),
                  if (_sections.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildResultsHeader(),
                    const SizedBox(height: 12),
                    ..._sections.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildSectionCard(s),
                      ),
                    ),
                  ] else if (_rawResult.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildRawResult(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 80,
      backgroundColor: const Color(0xFF0891B2),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0891B2), Color(0xFF0E7490)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Lab Values Interpreter',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'AI-powered clinical interpretation of lab results',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimerBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Color(0xFFE65100)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'For clinical decision support only. Always correlate with patient presentation and consult relevant specialists for critical values.',
              style: TextStyle(fontSize: 12, color: Color(0xFF5D4037), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    final hint = _panelHints[_selectedPanel] ?? 'Paste lab values here...';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel selector
          const Text('Panel Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedPanel,
            isExpanded: true,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF0FDFF),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFBAE6FD))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFBAE6FD))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0891B2), width: 1.5)),
            ),
            items: _panels.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) { if (v != null) setState(() => _selectedPanel = v); },
          ),
          const SizedBox(height: 16),
          // Lab values input
          Row(
            children: [
              const Icon(Icons.science_outlined, size: 15, color: Color(0xFF0891B2)),
              const SizedBox(width: 6),
              const Text('Lab Values', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    _labInputCtrl.text = data!.text!;
                  }
                },
                child: const Row(
                  children: [
                    Icon(Icons.content_paste, size: 14, color: Color(0xFF0891B2)),
                    SizedBox(width: 4),
                    Text('Paste', style: TextStyle(fontSize: 12, color: Color(0xFF0891B2), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _labInputCtrl,
            maxLines: 8,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFF1F2937)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0891B2), width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          // Clinical context
          const Row(
            children: [
              Icon(Icons.person_outline, size: 15, color: Color(0xFF6B7280)),
              SizedBox(width: 6),
              Text('Clinical Context (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _clinicalContextCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
            decoration: InputDecoration(
              hintText: 'e.g. 45yo M with fatigue and dyspnea on exertion × 2 weeks',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0891B2), width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterpretButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isInterpreting ? null : _interpret,
        icon: _isInterpreting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.biotech, size: 20),
        label: Text(_isInterpreting ? 'Interpreting...' : 'Interpret Lab Values'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0891B2),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Row(
      children: [
        const Icon(Icons.science, color: Color(0xFF0891B2), size: 20),
        const SizedBox(width: 8),
        const Text('Interpretation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
        const Spacer(),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _rawResult));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard'), behavior: SnackBarBehavior.floating),
            );
          },
          child: const Row(
            children: [
              Icon(Icons.copy, size: 16, color: Color(0xFF0891B2)),
              SizedBox(width: 4),
              Text('Copy', style: TextStyle(color: Color(0xFF0891B2), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(_LabSection section) {
    final isCritical = section.title.contains('CRITICAL');
    return Container(
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFFF5F5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCritical ? const Color(0xFFEF4444).withValues(alpha: 0.4) : section.color.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: section.color.withValues(alpha: isCritical ? 0.12 : 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(section.icon, size: 18, color: section.color),
                const SizedBox(width: 8),
                Text(
                  section.title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: section.color),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              section.content,
              style: const TextStyle(fontSize: 13.5, height: 1.55, color: Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawResult() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0891B2).withValues(alpha: 0.2)),
      ),
      child: SelectableText(
        _rawResult,
        style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF1F2937)),
      ),
    );
  }
}

class _LabSection {
  final String title;
  final String content;
  final IconData icon;
  final Color color;

  const _LabSection({
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
  });
}
