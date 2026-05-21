/// Parses AI-generated consultation text into structured clinical data.
library;

class ClinicalSummaryData {
  final String chiefComplaint;
  final String hpi;
  final String findings;
  final String assessment;
  final String plan;
  final List<String> safetyFlags;
  final List<String> followUp;
  final List<String> missing;
  final String overview;
  final bool hasStructuredContent;

  const ClinicalSummaryData({
    this.chiefComplaint = '',
    this.hpi = '',
    this.findings = '',
    this.assessment = '',
    this.plan = '',
    this.safetyFlags = const [],
    this.followUp = const [],
    this.missing = const [],
    this.overview = '',
    this.hasStructuredContent = false,
  });

  List<String> get missingOrIncomplete {
    final items = <String>[...missing];
    if (chiefComplaint.trim().isEmpty) items.add('Chief complaint');
    if (hpi.trim().isEmpty) items.add('History of present illness');
    if (assessment.trim().isEmpty) items.add('Assessment');
    if (plan.trim().isEmpty) items.add('Plan');
    return items;
  }
}

class PrescriptionData {
  final List<String> medications;
  final List<String> tests;
  final List<String> instructions;
  final List<String> warnings;
  final List<String> otcSuggestions;
  final List<String> missing;

  const PrescriptionData({
    this.medications = const [],
    this.tests = const [],
    this.instructions = const [],
    this.warnings = const [],
    this.otcSuggestions = const [],
    this.missing = const [],
  });
}

class TranscriptUtterance {
  final String speaker;
  final String text;

  const TranscriptUtterance({required this.speaker, required this.text});
}

class TranscriptInsights {
  final List<TranscriptUtterance> utterances;
  final List<String> symptoms;
  final List<String> keyPhrases;
  final int wordCount;
  final int estimatedMinutes;
  final String patientSummary;

  const TranscriptInsights({
    this.utterances = const [],
    this.symptoms = const [],
    this.keyPhrases = const [],
    this.wordCount = 0,
    this.estimatedMinutes = 0,
    this.patientSummary = '',
  });

  int get doctorCount => utterances.where((u) => u.speaker == 'Doctor').length;
  int get patientCount => utterances.where((u) => u.speaker == 'Patient').length;
  // "Other" counts Unknown + Speaker-N labels that weren't classified.
  int get otherCount => utterances.where((u) => u.speaker != 'Doctor' && u.speaker != 'Patient').length;
}

class ClinicalTextParser {
  static ClinicalSummaryData parseSummary(String input) {
    if (input.trim().isEmpty) return const ClinicalSummaryData();

    final sections = _extractSections(input, _summarySectionKeys);
    final chief = _joinSection(sections, ['chief', 'complaint', 'concern']);
    final hpi = _joinSection(sections, ['hpi', 'history', 'illness']);
    final findings = _joinSection(sections, ['finding', 'observation', 'exam']);
    final assessment = _joinSection(sections, ['assessment', 'impression', 'diagnosis']);
    final plan = _joinSection(sections, ['plan', 'treatment', 'recommendation', 'next']);
    final safety = _joinSection(sections, ['safety', 'red flag', 'warning', 'caution']);
    final follow = _joinSection(sections, ['follow', 'referral']);

    final missing = <String>[];
    for (final entry in sections.entries) {
      if (entry.key.contains('missing') || entry.key.contains('insufficient')) {
        missing.addAll(entry.value.where((l) => !_isPlaceholderLine(l)));
      }
    }
    for (final line in _lines(input)) {
      if (_isMissingLine(line)) missing.add(_stripBullet(line));
    }

    final hasContent = [chief, hpi, findings, assessment, plan]
        .any((s) => s.trim().isNotEmpty && !_isPlaceholderLine(s));

    var overview = '';
    if (!hasContent) {
      overview = _stripMarkdown(input);
      if (overview.length > 320) overview = '${overview.substring(0, 320).trim()}…';
    }

    return ClinicalSummaryData(
      chiefComplaint: chief,
      hpi: hpi,
      findings: findings,
      assessment: assessment,
      plan: plan,
      safetyFlags: _splitLines(safety),
      followUp: _splitLines(follow),
      missing: missing,
      overview: overview,
      hasStructuredContent: hasContent,
    );
  }

  static PrescriptionData parsePrescription(String input) {
    if (input.trim().isEmpty) return const PrescriptionData();

    final sections = _extractSections(input, _prescriptionSectionKeys);
    var medications = <String>[];
    var tests = <String>[];
    var instructions = <String>[];
    var warnings = <String>[];
    var otc = <String>[];
    var missing = <String>[];

    for (final entry in sections.entries) {
      final key = entry.key;
      final lines = entry.value.where((l) => l.trim().isNotEmpty && !_isPlaceholderLine(l)).toList();
      if (lines.isEmpty) continue;

      if (_keyMatches(key, ['medication', 'prescription', 'rx', 'drug'])) {
        medications.addAll(lines);
      } else if (_keyMatches(key, ['test', 'diagnostic', 'investigation', 'lab', 'imaging'])) {
        tests.addAll(lines);
      } else if (_keyMatches(key, ['instruction', 'education', 'follow', 'lifestyle', 'counsel'])) {
        instructions.addAll(lines);
      } else if (_keyMatches(key, ['warning', 'caution', 'contraindication', 'interaction', 'disclaimer', 'safety'])) {
        warnings.addAll(lines);
      } else if (_keyMatches(key, ['otc', 'over-the-counter', 'self-care', 'home care'])) {
        otc.addAll(lines);
      } else if (_keyMatches(key, ['missing', 'insufficient'])) {
        missing.addAll(lines);
      } else {
        for (final line in lines) {
          _bucketPrescriptionLine(line, medications, tests, instructions, warnings, otc);
        }
      }
    }

    for (final line in _lines(input)) {
      if (_isMissingLine(line)) {
        missing.add(_stripBullet(line));
        continue;
      }
      if (sections.isNotEmpty) continue;
      _bucketPrescriptionLine(_stripBullet(line), medications, tests, instructions, warnings, otc);
    }

    medications = _dedupe(medications);
    tests = _dedupe(tests);
    instructions = _dedupe(instructions);
    warnings = _dedupe(warnings);
    otc = _dedupe(otc);

    if (otc.isNotEmpty) {
      medications = [...medications, ...otc];
      otc = [];
    }

    return PrescriptionData(
      medications: medications,
      tests: tests,
      instructions: instructions,
      warnings: warnings,
      otcSuggestions: otc,
      missing: _dedupe(missing),
    );
  }

  static TranscriptInsights parseTranscript(String input) {
    if (input.trim().isEmpty) {
      return const TranscriptInsights();
    }

    final utterances = _parseUtterances(input);
    final words = input.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final minutes = (words / 130).ceil().clamp(1, 999);
    final symptoms = _extractSymptoms(input);
    final keyPhrases = _extractKeyPhrases(utterances);

    var patientSummary = '';
    final patientLines = utterances.where((u) => u.speaker == 'Patient').map((u) => u.text);
    if (patientLines.isNotEmpty) {
      patientSummary = patientLines.join(' ');
    } else if (utterances.isNotEmpty) {
      patientSummary = utterances.first.text;
    }
    if (patientSummary.length > 200) {
      patientSummary = '${patientSummary.substring(0, 200).trim()}…';
    }

    return TranscriptInsights(
      utterances: utterances,
      symptoms: symptoms,
      keyPhrases: keyPhrases,
      wordCount: words,
      estimatedMinutes: minutes,
      patientSummary: patientSummary,
    );
  }

  static final Map<String, List<String>> _summarySectionKeys = {
    'chief': ['chief complaint', 'chief concerns', 'chief concern', 'presenting complaint', 'reason for visit'],
    'hpi': ['hpi', 'history of present illness', 'history of illness', 'present illness'],
    'findings': ['findings', 'observations', 'clinical findings', 'physical exam', 'examination'],
    'assessment': ['assessment', 'clinical assessment', 'impression', 'diagnosis', 'clinical impression'],
    'plan': ['plan', 'treatment plan', 'management plan', 'next steps', 'recommendations', 'plan and next'],
    'safety': ['safety flags', 'safety', 'red flag', 'warning signs'],
    'follow': ['follow-up', 'follow up', 'referral'],
    'missing': ['missing details', 'insufficient data'],
  };

  static final Map<String, List<String>> _prescriptionSectionKeys = {
    'medications': ['prescription recommendations', 'medications', 'medication', 'rx', 'drugs prescribed'],
    'tests': ['tests and diagnostics', 'tests', 'diagnostics', 'investigations', 'lab orders', 'imaging'],
    'instructions': ['patient education', 'instructions', 'follow-up instructions', 'counseling', 'advice'],
    'warnings': ['cautions', 'contraindications', 'warnings', 'drug interactions', 'disclaimer'],
    'otc': ['otc', 'over-the-counter', 'self-care', 'home remedies'],
    'missing': ['missing details', 'insufficient data'],
  };

  static Map<String, List<String>> _extractSections(String input, Map<String, List<String>> aliases) {
    final result = <String, List<String>>{};
    String? currentKey;

    for (final raw in _lines(input)) {
      final line = _stripBullet(raw);
      if (line.isEmpty) continue;

      final headingKey = _matchHeading(line, aliases);
      if (headingKey != null) {
        currentKey = headingKey;
        result.putIfAbsent(currentKey, () => []);
        final afterColon = _textAfterColon(line);
        if (afterColon.isNotEmpty && !_isPlaceholderLine(afterColon)) {
          result[currentKey]!.add(afterColon);
        }
        continue;
      }

      if (currentKey != null) {
        result.putIfAbsent(currentKey, () => []);
        if (!_isPlaceholderLine(line)) result[currentKey]!.add(line);
      }
    }

    return result;
  }

  static String? _matchHeading(String line, Map<String, List<String>> aliases) {
    var normalized = _stripMarkdown(line).toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'^#+\s*'), '').trim();
    if (normalized.endsWith(':')) normalized = normalized.substring(0, normalized.length - 1).trim();

    for (final entry in aliases.entries) {
      for (final alias in entry.value) {
        if (normalized == alias || normalized.startsWith('$alias:') || normalized.startsWith(alias)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  static String _joinSection(Map<String, List<String>> sections, List<String> keyParts) {
    final parts = <String>[];
    for (final entry in sections.entries) {
      if (keyParts.any((p) => entry.key.contains(p))) {
        parts.addAll(entry.value);
      }
    }
    return parts.join('\n').trim();
  }

  static bool _keyMatches(String key, List<String> parts) =>
      parts.any((p) => key.contains(p));

  static void _bucketPrescriptionLine(
    String line,
    List<String> medications,
    List<String> tests,
    List<String> instructions,
    List<String> warnings,
    List<String> otc,
  ) {
    final lower = line.toLowerCase();
    if (_isMissingLine(line)) return;

    if (_looksLikeWarning(lower)) {
      warnings.add(line);
    } else if (_looksLikeTest(lower) && !_looksLikeMedication(lower)) {
      tests.add(line);
    } else if (_looksLikeMedication(lower) || _containsDrugName(lower)) {
      medications.add(line);
    } else if (_looksLikeInstruction(lower)) {
      instructions.add(line);
    } else if (lower.contains('otc') || lower.contains('over-the-counter')) {
      otc.add(line);
    } else {
      instructions.add(line);
    }
  }

  static bool _looksLikeMedication(String v) =>
      RegExp(r'\b\d+\s*mg\b').hasMatch(v) ||
      v.contains('tablet') ||
      v.contains('capsule') ||
      v.contains('take ') ||
      v.contains('twice daily') ||
      v.contains('once daily') ||
      v.contains('dosage') ||
      v.contains('**medication');

  static bool _containsDrugName(String v) {
    const drugs = [
      'acetaminophen', 'tylenol', 'ibuprofen', 'advil', 'motrin',
      'amoxicillin', 'azithromycin', 'metformin', 'atorvastatin',
      'dextromethorphan', 'guaifenesin', 'paracetamol', 'aspirin',
      'antibiotic', 'antihistamine', 'inhaler', 'insulin',
    ];
    return drugs.any(v.contains);
  }

  static bool _looksLikeTest(String v) {
    if (_looksLikeMedication(v) || _containsDrugName(v)) return false;
    return RegExp(r'\b(cbc|lft|kft|lipid panel|x-?ray|mri|ct scan|blood test|urinalysis)\b')
            .hasMatch(v) ||
        (v.contains(' lab ') || v.startsWith('lab ')) ||
        (v.contains('order') && v.contains('test'));
  }

  static bool _looksLikeWarning(String v) =>
      v.contains('avoid') ||
      v.contains('allergy') ||
      v.contains('contraind') ||
      v.contains('warning') ||
      v.contains('disclaimer') ||
      v.contains('ai-generated');

  static bool _looksLikeInstruction(String v) =>
      v.contains('follow up') ||
      v.contains('follow-up') ||
      v.contains('return if') ||
      v.contains('seek medical') ||
      v.contains('rest and') ||
      v.contains('hydration') ||
      v.contains('monitor');

  // Matches both "[Doctor]:" (pipeline output) and plain "Doctor:" formats.
  // Also handles "Dr.", "pt.", "Unknown", "Speaker N" variants.
  static final _speakerLineRe = RegExp(
    r'^\[?(?<label>[^\]:]+?)\]?\s*:\s*(?<text>.+)$',
    caseSensitive: false,
  );

  static String _normaliseSpeakerLabel(String raw) {
    final lower = raw.trim().toLowerCase();
    if (RegExp(r'^dr\.?$|^doctor$').hasMatch(lower)) return 'Doctor';
    if (RegExp(r'^pt\.?$|^patient$').hasMatch(lower)) return 'Patient';
    if (lower == 'unknown') return 'Other';
    // "Speaker 0", "Speaker 1", etc. — keep as-is so caller can display them
    return raw.trim();
  }

  static List<TranscriptUtterance> _parseUtterances(String input) {
    final utterances = <TranscriptUtterance>[];
    final lines = _lines(input);

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final m = _speakerLineRe.firstMatch(line);
      if (m != null) {
        final label = _normaliseSpeakerLabel(m.namedGroup('label') ?? '');
        final text = (m.namedGroup('text') ?? '').trim();
        if (label.isNotEmpty && text.isNotEmpty) {
          utterances.add(TranscriptUtterance(speaker: label, text: text));
          continue;
        }
      }
      // Line has no speaker prefix — treat as continuation or plain text.
      if (utterances.isNotEmpty) {
        // Append to the last speaker's utterance rather than creating an
        // orphan "Other" line for mid-sentence Deepgram line breaks.
        final last = utterances.last;
        utterances[utterances.length - 1] =
            TranscriptUtterance(speaker: last.speaker, text: '${last.text} $line');
      } else {
        utterances.add(TranscriptUtterance(speaker: 'Other', text: line));
      }
    }

    if (utterances.isEmpty) return utterances;

    // Merge consecutive lines from the same speaker into one utterance.
    // Deepgram sometimes splits a single sentence across multiple lines
    // (e.g. "The patient is having a serious," / "stomachache.") — these
    // should appear as one chat bubble, not two.
    final merged = <TranscriptUtterance>[];
    for (final u in utterances) {
      if (merged.isNotEmpty && merged.last.speaker == u.speaker) {
        final last = merged.last;
        merged[merged.length - 1] = TranscriptUtterance(
          speaker: last.speaker,
          text: '${last.text} ${u.text}',
        );
      } else {
        merged.add(u);
      }
    }
    final utterances2 = merged;

    // If every line parsed as "Other", the transcript has no speaker labels
    // at all (raw Deepgram fallback). Split by sentence and infer from
    // clinical language cues.
    final allOther = utterances2.every((u) => u.speaker == 'Other');
    if (!allOther) return utterances2;

    final fullText = utterances2.map((u) => u.text).join(' ');
    final sentences = fullText
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().length > 8)
        .toList();

    if (sentences.length <= 1) {
      return [TranscriptUtterance(speaker: 'Other', text: fullText.trim())];
    }

    return sentences
        .map((s) => TranscriptUtterance(speaker: _inferSpeaker(s.trim()), text: s.trim()))
        .toList();
  }

  static String _inferSpeaker(String sentence) {
    final lower = sentence.toLowerCase();
    const doctorCues = [
      'i recommend', 'we should', 'let me examine', 'prescribe', 'order a',
      'you should take', 'follow up in', 'any allergies', 'how long have',
    ];
    if (doctorCues.any(lower.contains)) return 'Doctor';
    return 'Patient';
  }

  static List<String> _extractSymptoms(String text) {
    const keywords = [
      'cough', 'fever', 'cold', 'pain', 'headache', 'nausea', 'vomiting',
      'fatigue', 'sore throat', 'congestion', 'breathless', 'chest pain',
      'dizziness', 'rash', 'swelling', 'infection',
    ];
    final lower = text.toLowerCase();
    return keywords.where(lower.contains).map((k) => _capitalize(k)).toList();
  }

  static List<String> _extractKeyPhrases(List<TranscriptUtterance> utterances) {
    final phrases = <String>[];
    for (final u in utterances) {
      final text = u.text.trim();
      if (text.length < 12) continue;
      phrases.add(text.length > 90 ? '${text.substring(0, 90)}…' : text);
      if (phrases.length >= 4) break;
    }
    return phrases;
  }

  static List<String> _lines(String input) => input.replaceAll('\r\n', '\n').split('\n');

  static String _stripBullet(String line) =>
      line.trim().replaceFirst(RegExp(r'^[-*•]\s+'), '').trim();

  static String _stripMarkdown(String text) =>
      text.replaceAll(RegExp(r'[#*_`>]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _textAfterColon(String line) {
    final idx = line.indexOf(':');
    if (idx == -1) return '';
    return line.substring(idx + 1).trim();
  }

  static bool _isPlaceholderLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('not specified') ||
        lower.contains('not available') ||
        lower.contains('insufficient data') ||
        lower.contains('no details provided') ||
        lower.contains('n/a');
  }

  static bool _isMissingLine(String line) {
    final lower = line.toLowerCase();
    return lower.startsWith('missing') || lower.contains('insufficient data');
  }

  static List<String> _splitLines(String block) {
    if (block.trim().isEmpty) return [];
    return block
        .split('\n')
        .map(_stripBullet)
        .where((l) => l.isNotEmpty && !_isPlaceholderLine(l))
        .toList();
  }

  static List<String> _dedupe(List<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in items) {
      final key = item.toLowerCase().trim();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(item.trim());
    }
    return out;
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
