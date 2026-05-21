import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fhir_config_service.dart';

class FhirClient {
  final FhirConfig config;

  const FhirClient(this.config);

  Future<Map<String, dynamic>> readResource(String resourceType, String id) async {
    final uri = _buildUri('/$resourceType/$id');
    return _getJson(uri);
  }

  Future<List<Map<String, dynamic>>> search(
    String resourceType, {
    Map<String, String> query = const {},
  }) async {
    final uri = _buildUri('/$resourceType', query: query);
    final json = await _getJson(uri);
    final entries = json['entry'];
    if (entries is! List) return const [];
    return entries
        .map((e) => e is Map<String, dynamic> ? e['resource'] : null)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${config.accessToken}',
        'Accept': 'application/fhir+json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('FHIR request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('FHIR response format error');
  }

  Uri _buildUri(String path, {Map<String, String> query = const {}}) {
    final base = config.baseUrl.trim();
    final sanitized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final fullPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$sanitized$fullPath');
    if (query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }
}
