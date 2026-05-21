import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class RxNormService {
  static const String _defaultBaseUrl = 'https://rxnav.nlm.nih.gov/REST';

  Future<String?> getRxcuiForName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final baseUrl = _env('RXNORM_BASE_URL', fallback: _defaultBaseUrl);
    final uri = Uri.parse('$baseUrl/rxcui.json').replace(queryParameters: {
      'name': trimmed,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final idGroup = decoded['idGroup'] as Map<String, dynamic>?;
      final rxcuies = idGroup?['rxnormId'] as List<dynamic>?;
      if (rxcuies == null || rxcuies.isEmpty) return null;
      return rxcuies.first.toString();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RxNormService] Failed to resolve rxcui: $e');
      }
      return null;
    }
  }

  String _env(String key, {String fallback = ''}) {
    try {
      return dotenv.env[key] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
