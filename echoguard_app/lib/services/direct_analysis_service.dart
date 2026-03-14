import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';

/// Calls Mercury/Inception API directly from the phone.
/// No local Python/FastAPI backend required — works for every phone worldwide.
/// Images are passed directly to Mercury's Vision-Language Model.
class DirectAnalysisService {
  // ── API keys ────────────────────────────────────────────────────────────
  // Gemini/ML Kit removed. We use 100% Inception VLM.
  static const String _mercuryKey = 'sk_0f303a19575726c1579d899453ad8c37';

  static const String _mercuryUrl =
      'https://api.inceptionlabs.ai/v1/chat/completions';

  // ── Mercury system prompt (matches the backend logic) ───────────────────
  static const String _systemPrompt = '''
You are an AI fact-checker and media credibility analyzer. Analyze the provided text and return ONLY valid JSON with this exact structure:
{
  "credibility": <number 0-100>,
  "fake_probability": <number 0-100>,
  "manipulation": {
    "level": "<LOW|MEDIUM|HIGH>",
    "emotion": "<dominant emotion>",
    "intensity": <number 0-100>,
    "keywords": ["<word1>","<word2>"]
  },
  "bias": {
    "leaning": "<LEFT|CENTER|RIGHT|NEUTRAL>",
    "confidence": <number 0-100>,
    "propaganda_flag": <true|false>
  },
  "source_reliability": {
    "level": "<LOW|MEDIUM|HIGH>",
    "score": <number 0-100>,
    "domain": "<source domain or unknown>"
  },
  "clickbait": {
    "is_clickbait": <true|false>,
    "probability": <number 0-100>
  },
  "balanced_views": ["<alternative perspective 1>", "<alternative perspective 2>"],
  "ai_reasoning": "<2-3 sentence explanation of your credibility assessment>"
}
Return ONLY the JSON object. No markdown, no explanation, no extra text.
''';

  // ────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ────────────────────────────────────────────────────────────────────────

  /// Analyze plain text or a news claim.
  static Future<AnalysisResult> analyzeText(String text) async {
    if (text.trim().isEmpty) throw Exception('No text provided.');
    final json = await _callMercury(text.trim());
    return _parseResult(json);
  }

  /// Analyze a URL: fetch page text first, then fact-check.
  static Future<AnalysisResult> analyzeUrl(String url) async {
    // Try to grab page text via a simple GET (CORS may block on web — fine for mobile)
    String pageText;
    try {
      final resp = await http.get(Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 15));
      // Strip HTML tags with a basic regex
      pageText = resp.body
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (pageText.length > 4000) pageText = pageText.substring(0, 4000);
    } catch (_) {
      pageText = url; // fall back to just checking the URL itself
    }
    final json = await _callMercury('Article from $url:\n$pageText');
    return _parseResult(json);
  }

  /// Analyze an image: Pass directly to Mercury VLM.
  static Future<AnalysisResult> analyzeImage(String base64Image) async {
    // Mercury natively supports images, no local OCR or Gemini needed anymore.
    final json = await _callMercuryImage(base64Image);
    final result = _parseResult(json);
    return AnalysisResult(
      credibility: result.credibility,
      fakeProbability: result.fakeProbability,
      manipulation: result.manipulation,
      bias: result.bias,
      sourceReliability: result.sourceReliability,
      clickbait: result.clickbait,
      balancedViews: result.balancedViews,
      aiReasoning: result.aiReasoning,
      extractedText: "Image analyzed by Inception VLM",
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ────────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _callMercuryImage(String base64Image) async {
    final mimeType = _detectMime(base64Image);
    final base64Url = 'data:$mimeType;base64,$base64Image';

    final requestBody = {
      "model": "inception-v1", 
      "messages": [
        {
          "role": "system",
          "content":
              "Analyze the provided news image/screenshot for credibility and return ONLY a valid JSON object matching the exact format: "
              "{\"credibility\": number (0-100), \"fake_probability\": number (0-100), \"manipulation\": string, "
              "\"bias\": string, \"source_reliability\": string, \"clickbait\": string, \"balanced_views\": string, "
              "\"ai_reasoning\": string}. Do not include markdown code blocks. Make sure to read all text in the image."
        },
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text": "Analyze this news content:"
            },
            {
              "type": "image_url",
              "image_url": {
                "url": base64Url
              }
            }
          ]
        }
      ],
      "temperature": 0.0,
      "max_tokens": 1024,
      "response_format": {"type": "json_object"}
    };

    final resp = await http.post(
      Uri.parse(_mercuryUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_mercuryKey',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 45));

    if (resp.statusCode != 200) {
      throw Exception('Mercury Vision API error ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    final content = data['choices']?[0]?['message']?['content'] ?? '{}';
    return jsonDecode(content);
  }

  static Future<Map<String, dynamic>> _callMercury(String text) async {
    final resp = await http.post(
      Uri.parse(_mercuryUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_mercuryKey',
      },
      body: jsonEncode({
        'model': 'mercury-coder-small',
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': 'Analyze this content: $text'},
        ],
        'max_tokens': 1024,
        'temperature': 0.3,
      }),
    ).timeout(const Duration(seconds: 45));

    if (resp.statusCode != 200) {
      throw Exception('Mercury API error ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body);
    final content =
        data['choices']?[0]?['message']?['content'] as String? ?? '{}';

    // Strip markdown code fences if present
    final cleaned = content
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  static AnalysisResult _parseResult(Map<String, dynamic> j) {
    double _d(dynamic v, [double def = 0]) =>
        v == null ? def : (v as num).toDouble();
    bool _b(dynamic v, [bool def = false]) => v as bool? ?? def;
    String _s(dynamic v, [String def = '']) => v?.toString() ?? def;
    List<String> _ls(dynamic v) =>
        v == null ? [] : List<String>.from(v as List);

    final man = j['manipulation'] as Map<String, dynamic>? ?? {};
    final bias = j['bias'] as Map<String, dynamic>? ?? {};
    final src = j['source_reliability'] as Map<String, dynamic>? ?? {};
    final click = j['clickbait'] as Map<String, dynamic>? ?? {};

    return AnalysisResult(
      credibility: _d(j['credibility'], 50),
      fakeProbability: _d(j['fake_probability'], 50),
      manipulation: ManipulationData(
        level: _s(man['level'], 'LOW'),
        emotion: _s(man['emotion'], 'neutral'),
        intensity: _d(man['intensity'], 0),
        keywords: _ls(man['keywords']),
      ),
      bias: BiasData(
        leaning: _s(bias['leaning'], 'NEUTRAL'),
        confidence: _d(bias['confidence'], 50),
        propagandaFlag: _b(bias['propaganda_flag']),
      ),
      sourceReliability: SourceReliability(
        level: _s(src['level'], 'LOW'),
        score: (src['score'] as num?)?.toInt() ?? 0,
        domain: _s(src['domain'], 'unknown'),
      ),
      clickbait: ClickbaitData(
        isClickbait: _b(click['is_clickbait']),
        probability: _d(click['probability'], 0),
      ),
      balancedViews: _ls(j['balanced_views']),
      aiReasoning: _s(j['ai_reasoning'], 'Analysis complete.'),
    );
  }

  static String _detectMime(String b64) {
    try {
      final h = base64Decode(b64.length > 24 ? b64.substring(0, 24) : b64);
      if (h.length >= 2 && h[0] == 0xFF && h[1] == 0xD8) return 'image/jpeg';
      if (h.length >= 8 &&
          h[0] == 0x89 && h[1] == 0x50 && h[2] == 0x4E && h[3] == 0x47) {
        return 'image/png';
      }
      if (h.length >= 12 &&
          h[8] == 0x57 && h[9] == 0x45 && h[10] == 0x42 && h[11] == 0x50) {
        return 'image/webp';
      }
    } catch (_) {}
    return 'image/jpeg';
  }
}
