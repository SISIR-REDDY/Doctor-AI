import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;


class OpenFdaService {
  static const String _defaultBaseUrl = 'https://api.fda.gov/drug/label.json';

  Future<String> buildSafetyAppendix(List<String> medications) async {
    final lines = <String>[];
    for (final med in medications) {
      final warning = await _fetchWarnings(med);
      if (warning.isNotEmpty) {
        lines.add('Medication: $med');
        lines.add(warning);
      }
    }

    if (lines.isEmpty) return '';
    return '## FDA LABEL WARNINGS\n' + lines.join('\n\n');
  }

  Future<String> _fetchWarnings(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';

    final baseUrl = _env('OPENFDA_BASE_URL', fallback: _defaultBaseUrl);
    final apiKey = _env('OPENFDA_API_KEY');

    final search = _buildSearch(trimmed);
    final query = <String, String>{
      'search': search,
      'limit': '1',
    };
    if (apiKey.isNotEmpty) {
      query['api_key'] = apiKey;
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: query);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return '';
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = decoded['results'];
      if (results is! List || results.isEmpty) return '';
      final first = results.first as Map<String, dynamic>;
      final warnings = _extractField(first, 'warnings');
      final contraindications = _extractField(first, 'contraindications');
      final interactions = _extractField(first, 'drug_interactions');
      final boxed = _extractField(first, 'boxed_warning');

      final buffer = StringBuffer();
      if (boxed.isNotEmpty) buffer.writeln('Boxed Warning: $boxed');
      if (warnings.isNotEmpty) buffer.writeln('Warnings: $warnings');
      if (contraindications.isNotEmpty) buffer.writeln('Contraindications: $contraindications');
      if (interactions.isNotEmpty) buffer.writeln('Interactions: $interactions');

      return buffer.toString().trim();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OpenFdaService] Warning fetch failed: $e');
      }
      return '';
    }
  }

  String _buildSearch(String name) {
    final sanitized = name.replaceAll('(', '').replaceAll(')', '').trim();
    return 'openfda.generic_name:"$sanitized"+openfda.brand_name:"$sanitized"';
  }

  String _extractField(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is List && value.isNotEmpty) {
      return value.first.toString();
    }
    if (value is String) return value;
    return '';
  }

  String _env(String key, {String fallback = ''}) {
    try {
      return dotenv.env[key] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
