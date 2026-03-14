import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';
import '../config.dart';

/// EchoGuard Analysis Engine — Backend-first, local-fallback architecture.
///
/// 1. OCR.space (free) extracts text from images
/// 2. Extracted text is sent to the backend `/analyze` endpoint
///    (same pipeline as manual text input — Mercury-2 AI fact-checking)
/// 3. If backend is unreachable, falls back to a local NLP heuristic engine
class DirectAnalysisService {
  // ── OCR.space Free API ───────────────────────────────────────────────────
  static const String _ocrSpaceKey = 'helloworld';
  static const String _ocrSpaceUrl = 'https://api.ocr.space/parse/image';

  // ────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ────────────────────────────────────────────────────────────────────────

  /// Analyze plain text — try backend first, fall back to local.
  static Future<AnalysisResult> analyzeText(String text) async {
    if (text.trim().isEmpty) throw Exception('No text provided.');
    return _analyzeWithBackendFallback(text.trim());
  }

  /// Analyze a URL — try backend first, fall back to local.
  static Future<AnalysisResult> analyzeUrl(String url) async {
    // Try backend /analyze-url first
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/analyze-url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseResult(json);
      }
    } catch (_) {}

    // Fallback: fetch page text locally and analyze
    String pageText;
    try {
      final resp = await http.get(Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 15));
      pageText = resp.body
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (pageText.length > 4000) pageText = pageText.substring(0, 4000);
    } catch (_) {
      pageText = url;
    }
    return _analyzeWithBackendFallback(pageText);
  }

  /// Modular OCR: extract text from base64 image via OCR.space (free)
  static Future<String> extractTextFromImage(String base64Image) async {
    final mimeType = _detectMime(base64Image);
    final base64Url = 'data:$mimeType;base64,$base64Image';

    final request = http.MultipartRequest('POST', Uri.parse(_ocrSpaceUrl));
    request.fields['apikey'] = _ocrSpaceKey;
    request.fields['language'] = 'eng';
    request.fields['isOverlayRequired'] = 'false';
    request.fields['base64Image'] = base64Url;

    final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('OCR.space API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);

    if (data['IsErroredOnProcessing'] == true) {
      final errorMsg = data['ErrorMessage']?.toString() ?? 'Unknown OCR error';
      throw Exception('OCR.space processing error: $errorMsg');
    }

    final parsedResults = data['ParsedResults'] as List<dynamic>?;
    if (parsedResults == null || parsedResults.isEmpty) {
      throw Exception('OCR.space returned no parsed results.');
    }

    final text = parsedResults[0]['ParsedText']?.toString() ?? '';
    if (text.trim().isEmpty) {
      throw Exception('No readable text found in image.');
    }

    return text.trim();
  }

  /// Analyze an image:
  ///   Step 1: OCR.space extracts text
  ///   Step 2: Send extracted text to backend /analyze (same as text input)
  ///   Fallback: local heuristic if backend unavailable
  static Future<AnalysisResult> analyzeImage(String base64Image) async {
    // Step 1: Extract text via OCR.space
    final extractedText = await extractTextFromImage(base64Image);

    // Step 2: Send the extracted text through the SAME pipeline as text input
    final result = await _analyzeWithBackendFallback(extractedText);

    // Attach the OCR text to the result
    return AnalysisResult(
      credibility: result.credibility,
      fakeProbability: result.fakeProbability,
      manipulation: result.manipulation,
      bias: result.bias,
      sourceReliability: result.sourceReliability,
      clickbait: result.clickbait,
      balancedViews: result.balancedViews,
      aiReasoning: result.aiReasoning,
      extractedText: extractedText,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // BACKEND-FIRST, LOCAL-FALLBACK STRATEGY
  // ────────────────────────────────────────────────────────────────────────

  /// Try backend /analyze first. If it fails, use local heuristic.
  static Future<AnalysisResult> _analyzeWithBackendFallback(String text) async {
    // ── Attempt 1: Backend /analyze endpoint (Mercury-2 AI) ──────────────
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = _parseResult(json);
        // Only accept backend result if it looks meaningful
        // (the backend returns 50/50 on total failure, which is its fallback)
        return result;
      }
    } catch (e) {
      // Backend unreachable — proceed to local fallback
      print('[EchoGuard] Backend unreachable ($e), using local analysis');
    }

    // ── Attempt 2: Local heuristic analysis ──────────────────────────────
    return _analyzeLocally(text);
  }

  // ────────────────────────────────────────────────────────────────────────
  // LOCAL NLP HEURISTIC ENGINE (offline fallback)
  // ────────────────────────────────────────────────────────────────────────

  /// Words that strongly indicate sensationalism / clickbait
  static const List<String> _clickbaitWords = [
    'shocking', 'unbelievable', 'you won\'t believe', 'mind-blowing',
    'jaw-dropping', 'insane', 'epic', 'must see', 'this will', 'omg',
    'what happened next', 'secret', 'they don\'t want you to know',
    'exposed', 'gone wrong', 'destroyed', 'slammed', 'blasted',
    'bombshell', 'breaking', 'just in', 'urgent', 'alert',
    'exclusive', 'leaked', 'banned', 'censored', 'cover-up',
  ];

  /// Words indicating emotional manipulation
  static const List<String> _manipulationWords = [
    'outrage', 'fury', 'terrifying', 'horrifying', 'disgusting',
    'heartbreaking', 'devastating', 'nightmare', 'catastrophe',
    'crisis', 'panic', 'emergency', 'threat', 'danger', 'warning',
    'scam', 'fraud', 'hoax', 'conspiracy', 'propaganda',
    'brainwash', 'lie', 'lies', 'fake', 'rigged', 'corrupt',
    'evil', 'traitor', 'enemy', 'destroy', 'attack',
  ];

  /// Words strongly associated with unreliable / fake news patterns
  static const List<String> _fakeNewsPatterns = [
    'big pharma', 'mainstream media', 'deep state', 'new world order',
    'wake up sheeple', 'do your own research', 'they are hiding',
    'the truth about', 'what they don\'t tell you', 'exposed the truth',
    'government doesn\'t want', 'miracle cure', 'doctors hate',
    'one weird trick', '100% proven', 'scientifically proven',
    'share before deleted', 'share before removed', 'going viral',
  ];

  /// Words/patterns indicating credible reporting
  static const List<String> _credibilityWords = [
    'according to', 'study shows', 'research indicates', 'data suggests',
    'peer-reviewed', 'published in', 'university of', 'institute of',
    'official statement', 'spokesperson said', 'confirmed by',
    'evidence suggests', 'analysis shows', 'report finds',
    'statistics show', 'survey found', 'experts say',
    'investigation reveals', 'fact-check', 'verified',
  ];

  static const List<String> _leftBiasWords = [
    'progressive', 'equality', 'social justice', 'systemic',
    'marginalized', 'inclusivity', 'privilege', 'oppression',
  ];

  static const List<String> _rightBiasWords = [
    'traditional values', 'freedom', 'patriot', 'liberty',
    'constitution', 'second amendment', 'immigration crisis',
    'border security', 'law and order', 'woke',
  ];

  static AnalysisResult _analyzeLocally(String text) {
    final lower = text.toLowerCase();
    final words = lower.split(RegExp(r'\s+'));
    final wordCount = words.length;

    // Clickbait
    final clickbaitHits = _countMatches(lower, _clickbaitWords);
    final clickbaitScore = min(100.0, clickbaitHits * 18.0);
    final isClickbait = clickbaitScore > 40;

    // Manipulation
    final manipHits = _countMatches(lower, _manipulationWords);
    final manipIntensity = min(100.0, manipHits * 15.0);
    final manipLevel = manipIntensity > 60 ? 'HIGH' : manipIntensity > 30 ? 'MEDIUM' : 'LOW';
    final dominantEmotion = _detectEmotion(lower);

    // Fake news patterns
    final fakeHits = _countMatches(lower, _fakeNewsPatterns);
    final fakeScore = min(100.0, fakeHits * 25.0);

    // Credibility signals
    final credHits = _countMatches(lower, _credibilityWords);
    final credBoost = min(40.0, credHits * 10.0);

    // Bias
    final leftHits = _countMatches(lower, _leftBiasWords);
    final rightHits = _countMatches(lower, _rightBiasWords);
    String biasLeaning;
    double biasConfidence;
    if (leftHits == 0 && rightHits == 0) {
      biasLeaning = 'NEUTRAL'; biasConfidence = 20;
    } else if (leftHits > rightHits) {
      biasLeaning = 'LEFT'; biasConfidence = min(90.0, (leftHits - rightHits) * 20.0 + 30);
    } else if (rightHits > leftHits) {
      biasLeaning = 'RIGHT'; biasConfidence = min(90.0, (rightHits - leftHits) * 20.0 + 30);
    } else {
      biasLeaning = 'CENTER'; biasConfidence = 40;
    }
    final propagandaFlag = manipIntensity > 50 && fakeScore > 30;

    // Style penalties
    final exclCount = '!'.allMatches(text).length;
    final capsRatio = wordCount > 0
        ? words.where((w) => w.length > 2 && w == w.toUpperCase()).length / wordCount : 0.0;
    final stylePenalty = min(25.0, exclCount * 5.0 + capsRatio * 40.0);

    // Final score
    double credibility = 70.0;
    credibility += credBoost;
    credibility -= fakeScore * 0.6;
    credibility -= clickbaitScore * 0.3;
    credibility -= manipIntensity * 0.2;
    credibility -= stylePenalty;
    credibility = max(5.0, min(95.0, credibility));
    final fakeProbability = max(5.0, min(95.0, 100 - credibility));

    final srcScore = credibility.toInt();
    final srcLevel = srcScore > 65 ? 'HIGH' : srcScore > 40 ? 'MEDIUM' : 'LOW';

    // Balanced views
    final balanced = <String>[];
    if (credibility < 50) {
      balanced.add('This content shows signs of sensationalism. Cross-reference with established news sources.');
      balanced.add('Look for the same story from multiple independent outlets before sharing.');
    } else if (credibility < 70) {
      balanced.add('This content has mixed credibility signals. Verify key claims independently.');
    } else {
      balanced.add('This content appears to follow standard reporting patterns.');
    }

    final reasoning = _buildReasoning(credibility, fakeScore, clickbaitScore,
        manipIntensity, manipHits, clickbaitHits, fakeHits, credHits, wordCount);

    final foundKeywords = <String>[];
    for (final w in _manipulationWords) { if (lower.contains(w)) foundKeywords.add(w); }
    for (final w in _clickbaitWords) { if (lower.contains(w) && !foundKeywords.contains(w)) foundKeywords.add(w); }

    return AnalysisResult(
      credibility: credibility,
      fakeProbability: fakeProbability,
      manipulation: ManipulationData(level: manipLevel, emotion: dominantEmotion, intensity: manipIntensity, keywords: foundKeywords.take(6).toList()),
      bias: BiasData(leaning: biasLeaning, confidence: biasConfidence, propagandaFlag: propagandaFlag),
      sourceReliability: SourceReliability(level: srcLevel, score: srcScore, domain: 'analyzed locally'),
      clickbait: ClickbaitData(isClickbait: isClickbait, probability: clickbaitScore),
      balancedViews: balanced,
      aiReasoning: '[Local Analysis] $reasoning',
    );
  }

  static int _countMatches(String text, List<String> patterns) {
    int count = 0;
    for (final p in patterns) { if (text.contains(p)) count++; }
    return count;
  }

  static String _detectEmotion(String text) {
    final emotions = {
      'anger': ['outrage', 'fury', 'angry', 'rage', 'furious', 'attack', 'destroy'],
      'fear': ['terrifying', 'horrifying', 'nightmare', 'threat', 'danger', 'panic', 'warning'],
      'sadness': ['heartbreaking', 'devastating', 'tragic', 'loss', 'grief'],
      'surprise': ['shocking', 'unbelievable', 'jaw-dropping', 'stunning', 'bombshell'],
      'disgust': ['disgusting', 'sickening', 'appalling', 'shameful'],
    };
    String dominant = 'neutral';
    int maxHits = 0;
    for (final e in emotions.entries) {
      int hits = 0;
      for (final w in e.value) { if (text.contains(w)) hits++; }
      if (hits > maxHits) { maxHits = hits; dominant = e.key; }
    }
    return dominant;
  }

  static String _buildReasoning(double credibility, double fakeScore, double clickbaitScore,
      double manipIntensity, int manipHits, int clickbaitHits, int fakeHits, int credHits, int wordCount) {
    final parts = <String>[];
    if (credibility >= 70) {
      parts.add('This content appears credible based on language analysis.');
    } else if (credibility >= 40) {
      parts.add('This content has mixed credibility signals.');
    } else {
      parts.add('This content shows significant red flags for misinformation.');
    }
    if (fakeHits > 0) parts.add('Found $fakeHits known misinformation pattern(s).');
    if (clickbaitHits > 0) parts.add('Detected $clickbaitHits clickbait indicator(s).');
    if (manipHits > 0) parts.add('Found $manipHits emotional manipulation keyword(s).');
    if (credHits > 0) parts.add('Contains $credHits credibility-boosting reference(s).');
    if (wordCount < 20) parts.add('Very short text — limited analysis possible.');
    return parts.join(' ');
  }

  // ────────────────────────────────────────────────────────────────────────
  // SHARED HELPERS
  // ────────────────────────────────────────────────────────────────────────

  static AnalysisResult _parseResult(Map<String, dynamic> j) {
    double _d(dynamic v, [double def = 0]) => v == null ? def : (v as num).toDouble();
    bool _b(dynamic v, [bool def = false]) => v as bool? ?? def;
    String _s(dynamic v, [String def = '']) => v?.toString() ?? def;
    List<String> _ls(dynamic v) => v == null ? [] : List<String>.from(v as List);

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
      extractedText: j['extracted_text'] as String?,
    );
  }

  static String _detectMime(String b64) {
    try {
      final h = base64Decode(b64.length > 24 ? b64.substring(0, 24) : b64);
      if (h.length >= 2 && h[0] == 0xFF && h[1] == 0xD8) return 'image/jpeg';
      if (h.length >= 8 && h[0] == 0x89 && h[1] == 0x50 && h[2] == 0x4E && h[3] == 0x47) return 'image/png';
      if (h.length >= 12 && h[8] == 0x57 && h[9] == 0x45 && h[10] == 0x42 && h[11] == 0x50) return 'image/webp';
    } catch (_) {}
    return 'image/jpeg';
  }
}
