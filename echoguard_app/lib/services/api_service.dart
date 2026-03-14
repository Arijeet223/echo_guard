import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/analysis_result.dart';
import '../config.dart';

class ApiService {
  // Use central config; fallback to localhost for web browser testing
  static String get baseUrl =>
      kIsWeb ? AppConfig.localUrl : AppConfig.backendUrl;

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

  static Future<AnalysisResult> analyzeImage(String base64Image) async {
    final response = await http.post(
      Uri.parse('$baseUrl/analyze-image'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image_base64': base64Image}),
    );
    if (response.statusCode == 200) {
      return AnalysisResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to analyze image: ${response.statusCode}');
    }
  }

  static Future<AnalysisResult> analyzeUrl(String url) async {
    final response = await http.post(
      Uri.parse('$baseUrl/analyze-url'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    );
    if (response.statusCode == 200) {
      return AnalysisResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to analyze URL: ${response.statusCode}');
    }
  }
}
