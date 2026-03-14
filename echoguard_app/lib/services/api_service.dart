import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';
import '../config.dart';
import 'direct_analysis_service.dart';

/// Routes ALL calls directly to Gemini and Mercury.
/// No local backend needed, works on Web, Android, and iOS.
class ApiService {
  static Future<AnalysisResult> analyzeText(String text) async {
    return DirectAnalysisService.analyzeText(text);
  }

  static Future<AnalysisResult> analyzeImage(String base64Image) async {
    return DirectAnalysisService.analyzeImage(base64Image);
  }

  static Future<AnalysisResult> analyzeUrl(String url) async {
    return DirectAnalysisService.analyzeUrl(url);
  }

  static Future<void> sendFeedback(String feedback) async {
    // Best-effort; doesn't throw on failure
    try {
      await http.post(
        Uri.parse('${AppConfig.localUrl}/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'feedback': feedback}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
