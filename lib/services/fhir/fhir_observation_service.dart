import 'package:flutter/foundation.dart';

import 'fhir_client.dart';
import 'fhir_config_service.dart';

class FhirObservationService {
  final FhirConfigService _configService = FhirConfigService();

  Future<String> buildLabText({
    required String ehrPatientId,
  }) async {
    if (ehrPatientId.trim().isEmpty) return '';

    final config = await _configService.load();
    if (config == null || !config.isConfigured) {
      throw Exception('EHR not configured');
    }

    final client = FhirClient(config);
    final observations = await client.search(
      'Observation',
      query: {
        'patient': ehrPatientId.trim(),
        'category': 'laboratory',
        '_count': '50',
      },
    );

    if (observations.isEmpty) return '';

    final lines = <String>[];
    for (final obs in observations) {
      final label = _readCode(obs['code']);
      final value = _readValue(obs);
      if (label.isEmpty || value.isEmpty) continue;
      final range = _readReferenceRange(obs['referenceRange']);
      final line = range.isNotEmpty ? '$label: $value (ref $range)' : '$label: $value';
      lines.add(line);
    }

    return lines.join('\n');
  }

  String _readCode(Object? codeField) {
    if (codeField is Map<String, dynamic>) {
      final text = (codeField['text'] ?? '').toString();
      if (text.trim().isNotEmpty) return text.trim();
      final coding = codeField['coding'];
      if (coding is List && coding.isNotEmpty) {
        final first = coding.first;
        if (first is Map<String, dynamic>) {
          final display = (first['display'] ?? '').toString();
          if (display.trim().isNotEmpty) return display.trim();
        }
      }
    }
    return '';
  }

  String _readValue(Map<String, dynamic> obs) {
    final valueQuantity = obs['valueQuantity'];
    if (valueQuantity is Map<String, dynamic>) {
      final value = valueQuantity['value']?.toString() ?? '';
      final unit = valueQuantity['unit']?.toString() ?? '';
      if (value.isEmpty) return '';
      return unit.isEmpty ? value : '$value $unit';
    }

    final valueString = obs['valueString'];
    if (valueString != null) return valueString.toString();

    return '';
  }

  String _readReferenceRange(Object? rangeField) {
    if (rangeField is! List || rangeField.isEmpty) return '';
    final first = rangeField.first;
    if (first is! Map<String, dynamic>) return '';
    final low = first['low'] as Map<String, dynamic>?;
    final high = first['high'] as Map<String, dynamic>?;
    final lowVal = low?['value']?.toString() ?? '';
    final highVal = high?['value']?.toString() ?? '';
    if (lowVal.isEmpty && highVal.isEmpty) return '';
    if (lowVal.isNotEmpty && highVal.isNotEmpty) return '$lowVal-$highVal';
    return lowVal.isNotEmpty ? '>= $lowVal' : '<= $highVal';
  }
}
