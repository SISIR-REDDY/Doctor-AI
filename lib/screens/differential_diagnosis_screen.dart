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

class DifferentialDiagnosisScreen extends StatefulWidget {
  const DifferentialDiagnosisScreen({super.key});

  @override
  State<DifferentialDiagnosisScreen> createState() =>
      _DifferentialDiagnosisScreenState();
}

class _DifferentialDiagnosisScreenState
    extends State<DifferentialDiagnosisScreen> {
  final ChatbotService _chatbot = ChatbotService();
  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();

  final _chiefComplaintCtrl = TextEditingController();
  final _symptomsCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _pmhCtrl = TextEditingController();

  String _selectedGender = 'Not specified';
  String _selectedDuration = 'Acute (<24h)';
  bool _isGenerating = false;
  String _rawResult = '';
  List<_DiffItem> _parsedDiffs = [];

  static const _genders = ['Male', 'Female', 'Not specified'];
  static const _durations = [
    'Acute (<24h)',
    'Sub-acute (1–7 days)',
    'Chronic (>1 week)',
    'Intermittent',
  ];

  @override
  void dispose() {
    _chiefComplaintCtrl.dispose();
    _symptomsCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _pmhCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_chiefComplaintCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a chief complaint to generate differentials'),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _rawResult = '';
      _parsedDiffs = [];
    });

    try {
      final prompt = _buildPrompt();
      final result = await _chatbot.getGeminiResponse(prompt);

      if (!mounted) return;
      final parsed = _parseDifferentials(result);
      setState(() {
        _rawResult = result;
        _parsedDiffs = parsed;
        _isGenerating = false;
      });

      _autoSave(result);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      AppErrorHandler.showSnackBar(context, e);
    }
  }

  String _buildPrompt() {
    final age = _ageCtrl.text.trim();
    final weight = _weightCtrl.text.trim();
    final pmh = _pmhCtrl.text.trim();
    final symptoms = _symptomsCtrl.text.trim();

    return '''
You are an experienced clinical physician generating a structured differential diagnosis.

PATIENT:
- Chief Complaint: ${_chiefComplaintCtrl.text.trim()}
- Age: ${age.isEmpty ? 'Not provided' : '$age years'}
- Gender: $_selectedGender
- Weight: ${weight.isEmpty ? 'Not provided' : '${weight}kg'}
- Symptom Duration: $_selectedDuration
- Associated Symptoms: ${symptoms.isEmpty ? 'Not provided' : symptoms}
- Past Medical History: ${pmh.isEmpty ? 'Not provided' : pmh}

Generate a RANKED differential diagnosis. For each diagnosis provide:

DIAGNOSIS: [Name]
LIKELIHOOD: [High / Medium / Low]
SUPPORTING: [2-3 key features supporting this diagnosis]
AGAINST: [1-2 features arguing against]
WORKUP: [Immediate tests to confirm/exclude: e.g., CBC, ECG, CXR]
RED FLAGS: [Any urgent features to watch for]

List the top 5 most likely diagnoses in order of probability. After the list, add a MUST NOT MISS section with 2 serious diagnoses that must be excluded even if less likely.

Be concise and clinically precise. Use standard medical terminology.
''';
  }

  List<_DiffItem> _parseDifferentials(String text) {
    final items = <_DiffItem>[];
    // Split on DIAGNOSIS: blocks
    final blocks = text.split(RegExp(r'DIAGNOSIS:', caseSensitive: false));
    for (final block in blocks.skip(1)) {
      final name = _extract(block, null, ['LIKELIHOOD:', '\n']);
      final likelihood = _extract(block, 'LIKELIHOOD:', ['SUPPORTING:', '\n']);
      final supporting = _extract(block, 'SUPPORTING:', ['AGAINST:', 'WORKUP:']);
      final against = _extract(block, 'AGAINST:', ['WORKUP:', 'RED FLAGS:']);
      final workup = _extract(block, 'WORKUP:', ['RED FLAGS:', 'DIAGNOSIS:', 'MUST']);
      final redFlags = _extract(block, 'RED FLAGS:', ['DIAGNOSIS:', 'MUST', '\n\n\n']);

      if (name.isNotEmpty) {
        items.add(_DiffItem(
          name: name.trim(),
          likelihood: likelihood.trim(),
          supporting: supporting.trim(),
          against: against.trim(),
          workup: workup.trim(),
          redFlags: redFlags.trim(),
        ));
      }
    }
    return items;
  }

  String _extract(String text, String? startMarker, List<String> endMarkers) {
    String src = text;
    if (startMarker != null) {
      final idx = text.toUpperCase().indexOf(startMarker.toUpperCase());
      if (idx == -1) return '';
      src = text.substring(idx + startMarker.length);
    }

    int end = src.length;
    for (final marker in endMarkers) {
      final idx = src.toUpperCase().indexOf(marker.toUpperCase());
      if (idx != -1 && idx < end) end = idx;
    }
    return src.substring(0, end).trim();
  }

  Future<void> _autoSave(String result) async {
    try {
      final note = ClinicalNote(
        id: const Uuid().v4(),
        patientId: 'differential_diagnosis',
        title: 'DDx: ${_chiefComplaintCtrl.text.trim()} — ${DateFormat('MMM d, h:mm a').format(DateTime.now())}',
        content:
            'Chief Complaint: ${_chiefComplaintCtrl.text.trim()}\n'
            'Age: ${_ageCtrl.text.trim()} | Gender: $_selectedGender | Duration: $_selectedDuration\n'
            'Symptoms: ${_symptomsCtrl.text.trim()}\n\n'
            '--- DIFFERENTIAL DIAGNOSIS ---\n\n$result',
        diagnosis: 'Differential Diagnosis',
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
                  _buildInputCard(),
                  const SizedBox(height: 16),
                  _buildGenerateButton(),
                  if (_parsedDiffs.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildResultsHeader(),
                    const SizedBox(height: 12),
                    ..._parsedDiffs.asMap().entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildDiffCard(e.value, e.key),
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
      backgroundColor: const Color(0xFF6D28D9),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)],
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
                    'Differential Diagnosis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'AI-ranked DDx with workup recommendations',
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

  Widget _buildInputCard() {
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
          _sectionLabel('Chief Complaint', Icons.sick_outlined, const Color(0xFF6D28D9)),
          const SizedBox(height: 8),
          _textField(
            controller: _chiefComplaintCtrl,
            hint: 'e.g. Sudden onset chest pain, severe headache, dyspnea at rest...',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Age (yrs)', Icons.person_outline, Colors.grey),
                    const SizedBox(height: 8),
                    _textField(
                      controller: _ageCtrl,
                      hint: '45',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Weight (kg)', Icons.monitor_weight_outlined, Colors.grey),
                    const SizedBox(height: 8),
                    _textField(
                      controller: _weightCtrl,
                      hint: '70',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _dropdownField('Gender', _genders, _selectedGender, (v) => setState(() => _selectedGender = v!))),
              const SizedBox(width: 12),
              Expanded(child: _dropdownField('Duration', _durations, _selectedDuration, (v) => setState(() => _selectedDuration = v!))),
            ],
          ),
          const SizedBox(height: 16),
          _sectionLabel('Associated Symptoms', Icons.list_alt_outlined, Colors.grey),
          const SizedBox(height: 8),
          _textField(
            controller: _symptomsCtrl,
            hint: 'Nausea, diaphoresis, radiation to left arm, pleuritic component...',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _sectionLabel('Past Medical History', Icons.history_edu_outlined, Colors.grey),
          const SizedBox(height: 8),
          _textField(
            controller: _pmhCtrl,
            hint: 'HTN, DM2, prior MI, current medications...',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : _generate,
        icon: _isGenerating
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome, size: 20),
        label: Text(_isGenerating ? 'Generating differentials...' : 'Generate Differential Diagnosis'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6D28D9),
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
        const Icon(Icons.format_list_numbered, color: Color(0xFF6D28D9), size: 20),
        const SizedBox(width: 8),
        Text(
          '${_parsedDiffs.length} Differentials Generated',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
        ),
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
              Icon(Icons.copy, size: 16, color: Color(0xFF6D28D9)),
              SizedBox(width: 4),
              Text('Copy', style: TextStyle(color: Color(0xFF6D28D9), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiffCard(_DiffItem diff, int index) {
    final likelihood = diff.likelihood.toLowerCase();
    Color badgeColor;
    if (likelihood.contains('high')) {
      badgeColor = const Color(0xFFDC2626);
    } else if (likelihood.contains('medium')) {
      badgeColor = const Color(0xFFF59E0B);
    } else {
      badgeColor = const Color(0xFF22C55E);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    diff.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    diff.likelihood.isEmpty ? '—' : diff.likelihood,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (diff.supporting.isNotEmpty) _diffRow(Icons.check_circle_outline, const Color(0xFF22C55E), 'Supporting', diff.supporting),
                if (diff.against.isNotEmpty) _diffRow(Icons.cancel_outlined, const Color(0xFF6B7280), 'Against', diff.against),
                if (diff.workup.isNotEmpty) _diffRow(Icons.biotech_outlined, const Color(0xFF3B82F6), 'Workup', diff.workup),
                if (diff.redFlags.isNotEmpty) _diffRow(Icons.warning_amber_rounded, const Color(0xFFEF4444), 'Red Flags', diff.redFlags),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diffRow(IconData icon, Color color, String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                  ),
                  TextSpan(
                    text: text,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
                  ),
                ],
              ),
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
        border: Border.all(color: const Color(0xFF6D28D9).withValues(alpha: 0.2)),
      ),
      child: SelectableText(
        _rawResult,
        style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF1F2937)),
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5)),
      ),
    );
  }

  Widget _dropdownField(String label, List<String> items, String value, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5)),
          ),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DiffItem {
  final String name;
  final String likelihood;
  final String supporting;
  final String against;
  final String workup;
  final String redFlags;

  const _DiffItem({
    required this.name,
    required this.likelihood,
    required this.supporting,
    required this.against,
    required this.workup,
    required this.redFlags,
  });
}
