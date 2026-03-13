import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/analysis_result.dart';

class ApiService {
  // Auto-detect: localhost for web browser, LAN IP for mobile device
  static String get baseUrl =>
      kIsWeb ? 'http://127.0.0.1:8000' : 'http://172.16.62.104:8000';

  static Future<AnalysisResult> analyzeText(String text) async {
    final response = await http.post(
      Uri.parse('$baseUrl/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );

    if (response.statusCode == 200) {
      return AnalysisResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to analyze text: ${response.statusCode}');
    }
  }

  static Future<void> sendFeedback(String feedback) async {
    await http.post(
      Uri.parse('$baseUrl/feedback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'feedback': feedback}),
    );
  }
}
