import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';
import 'language_provider.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// Veritas Direct Analysis Service
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
///
/// PRIMARY:  Inception Labs Mercury-2 API  (direct from phone, no backend)
/// OCR:     OCR.space free API  (image → text extraction)
/// FALLBACK: Local NLP heuristic engine  (offline / API down)
///
/// Pipeline:
///   Text   →  Mercury-2  →  AnalysisResult
///   Image  →  OCR.space  →  Mercury-2  →  AnalysisResult  (same as text)
///   URL    →  HTTP fetch  →  Mercury-2  →  AnalysisResult  (same as text)
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class DirectAnalysisService {

  // ══════════════════════════════════════════════════════════════════════
  //  API CONFIGURATION
  // ══════════════════════════════════════════════════════════════════════

  /// Inception Labs Mercury-2 — the MAIN analyzer
  static const String _inceptionKey = 'sk_0f303a19575726c1579d899453ad8c37';
  static const String _inceptionUrl = 'https://api.inceptionlabs.ai/v1/chat/completions';
  static const String _inceptionModel = 'mercury-2';          // ← full model, NOT coder-small

  /// OCR.space — text extraction from images
  static const String _ocrSpaceKey = 'K86345433788957';
  static const String _ocrSpaceUrl = 'https://api.ocr.space/parse/image';

  /// News API keys (available for future use)
  // ignore: unused_field
  static const String _bbcNewsApiKey = 'pub_f6b47aba4b2a41fbba973a5bded2b884';
  // ignore: unused_field
  static const String _newsApiKey = '35e869935b2448848129c9ca5e306f52';

  // ══════════════════════════════════════════════════════════════════════
  //  SYSTEM PROMPT  (identical to main.py backend but with RAG instructions)
  // ══════════════════════════════════════════════════════════════════════

  static const String _systemPrompt = '''
You are Veritas, an advanced, highly-accurate AI fact-checking engine.
Analyze the user's claim. You are expected to provide the FINAL analysis.
Your primary directive: If live web search results are provided, you MUST prioritize them over your internal knowledge, as your training data cuts off in 2025. Does the scraped news confirm or refute the claim?
Do NOT output any intermediate search queries or tool calls.
You MUST output ONLY a single valid JSON object matching this exact structure:
{
  "credibility": <float between 0 and 100>,
  "fake_probability": <float between 0 and 100>,
  "manipulation": {
    "level": "<string: HIGH, MEDIUM, LOW>",
    "emotion": "<string: e.g., outrage, fear, neutral, excitement>",
    "intensity": <float between 0 and 100>,
    "keywords": ["<string>", "<string>"]
  },
  "bias": {
    "leaning": "<string: LEFT, RIGHT, NEUTRAL, BIAS-FREE>",
    "confidence": <float between 0 and 100>,
    "propaganda_flag": <boolean>
  },
  "source_reliability": {
    "level": "<string: HIGH, MEDIUM, LOW>",
    "score": <integer between 0 and 100>,
    "domain": "<string: primarily cross-referenced domain or unknown>"
  },
  "clickbait": {
    "is_clickbait": <boolean>,
    "probability": <float between 0 and 100>
  },
  "balanced_views": [
    "<string: Title of article - domain.com>",
    "<string: Title of article - domain.com>"
  ],
  "ai_reasoning": "<string: 2-3 sentences explaining your verdict based strongly on the live search results>"
}

Rules:
1. "credibility" is your main 0-100 score. 100=absolutely true, 0=absolutely false.
2. "balanced_views" must contain actual article headlines and domains from the search results, if provided.
3. Be objective. Your ENTIRE output must be the JSON object above. Do not output anything else.
''';

  // ══════════════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ══════════════════════════════════════════════════════════════════════

  /// Analyze plain text — Inception Mercury-2 primary (with web search), local fallback.
  static Future<AnalysisResult> analyzeText(String text) async {
    if (text.trim().isEmpty) throw Exception('No text provided.');
    return _analyzeViaInception(text.trim());
  }

  /// Analyze a URL — fetch page content, then run through Inception.
  static Future<AnalysisResult> analyzeUrl(String url) async {
    String pageText;
    try {
      final resp = await http.get(Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 15));
      pageText = resp.body
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (pageText.length > 4000) pageText = pageText.substring(0, 4000);
    } catch (_) {
      pageText = url;
    }
    return _analyzeViaInception('Article from $url:\n$pageText');
  }

  /// Analyze an image — OCR.space extracts text, then Inception analyzes it.
  static Future<AnalysisResult> analyzeImage(String base64Image) async {
    // ── Step 1: Extract text via OCR.space ──────────────────────────────
    final rawText = await extractTextFromImage(base64Image);
    print('[Veritas] OCR extracted ${rawText.length} chars');

    // ── Step 2: Structure/clean the extracted text ──────────────────────
    final cleanedText = _structureOcrText(rawText);
    print('[Veritas] Cleaned text: ${cleanedText.length} chars');

    // ── Step 3: Feed structured text into Inception ────────────────────
    final result = await _analyzeViaInception(cleanedText);

    // Attach the OCR text to the result for display
    return AnalysisResult(
      credibility: result.credibility,
      fakeProbability: result.fakeProbability,
      manipulation: result.manipulation,
      bias: result.bias,
      sourceReliability: result.sourceReliability,
      clickbait: result.clickbait,
      balancedViews: result.balancedViews,
      aiReasoning: result.aiReasoning,
      extractedText: rawText,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  TEXT STRUCTURING — Strip UI noise from OCR output
  // ══════════════════════════════════════════════════════════════════════

  /// Cleans raw OCR text by removing common screen UI artifacts,
  /// short garbage lines, and known noise patterns so only the
  /// actual news claim or article text remains for AI analysis.
  static String _structureOcrText(String raw) {
    // Noise patterns commonly found in mobile screenshots
    final noisePatterns = [
      RegExp(r'\d{1,2}:\d{2}\s*(AM|PM|am|pm)?', caseSensitive: false), // timestamps
      RegExp(r'\d{1,3}%'), // battery levels
      RegExp(r'(WiFi|LTE|4G|5G|\bVoLTE\b)', caseSensitive: false), // signal info
      RegExp(r'^(Like|Share|Reply|Retweet|Comment|Follow|Subscribe|Send|Save|Report)\s*\$', caseSensitive: false, multiLine: true),
      RegExp(r'^(Home|Search|Notifications|Messages|Profile|Settings|Menu|More)\s*\$', caseSensitive: false, multiLine: true),
      RegExp(r'^@\w+\s*\$', multiLine: true), // lone @usernames
      RegExp(r'^\d+[KkMm]?\s*(likes?|comments?|shares?|views?|retweets?|replies)\s*\$', caseSensitive: false, multiLine: true),
      RegExp(r'(\d+\s*(min|h|d|w|mo|yr)\s*ago)', caseSensitive: false), // relative timestamps
    ];

    // Split into lines and filter
    final lines = raw.split(RegExp(r'[\r\n]+'));
    final cleanedLines = <String>[];

    for (var line in lines) {
      var cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;
      if (cleanLine.length < 5) continue; // skip very short lines (UI labels)

      // Remove lines that are purely noise
      bool isNoise = false;
      for (final pattern in noisePatterns) {
        if (pattern.hasMatch(cleanLine) && cleanLine.length < 30) {
          isNoise = true;
          break;
        }
      }
      if (isNoise) continue;

      cleanedLines.add(cleanLine);
    }

    // Join the surviving lines into a coherent block
    final structured = cleanedLines.join(' ');

    // Final cleanup: collapse multiple spaces
    return structured.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// Extract text from a base64 image using OCR.space.
  static Future<String> extractTextFromImage(String base64Image) async {
    final mimeType = _detectMime(base64Image);
    final base64Url = 'data:$mimeType;base64,$base64Image';

    final request = http.MultipartRequest('POST', Uri.parse(_ocrSpaceUrl));
    request.fields['apikey'] = _ocrSpaceKey;
    request.fields['language'] = 'eng';
    request.fields['isOverlayRequired'] = 'false';
    request.fields['base64Image'] = base64Url;

    final streamedResponse = await request.send()
        .timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('OCR.space error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (data['IsErroredOnProcessing'] == true) {
      throw Exception('OCR error: ${data['ErrorMessage'] ?? 'Unknown'}');
    }

    final parsedResults = data['ParsedResults'] as List<dynamic>?;
    if (parsedResults == null || parsedResults.isEmpty) {
      throw Exception('OCR returned no results.');
    }

    final text = parsedResults[0]['ParsedText']?.toString() ?? '';
    if (text.trim().isEmpty) {
      throw Exception('No readable text found in image.');
    }
    return text.trim();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  LIVE WEB SEARCH (RAG)
  // ══════════════════════════════════════════════════════════════════════

  /// Scrapes latest news context from Google News RSS using a generated query
  static Future<String> _scrapeNews(String text) async {
    try {
      // Create a short search query from the first 100 chars (stripping common stopwords for better results)
      final cleanText = text.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
      final words = cleanText.split(RegExp(r'\s+'));
      final queryWords = words.take(8).where((w) => w.length > 2 && w.toLowerCase() != 'the' && w.toLowerCase() != 'and').toList();
      final query = Uri.encodeComponent(queryWords.join(' '));
      
      if (query.isEmpty) return 'No news query generated.';

      final url = 'https://news.google.com/rss/search?q=$query&hl=en-US&gl=US&ceid=US:en';
      print('[Veritas] Live News Web Search: $url');
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return 'News search failed (HTTP ${response.statusCode}).';

      final rss = response.body;
      
      // Simple regex extraction since we don't have an XML parser in pubspec
      final itemRegex = RegExp(r'<item>([\s\S]*?)<\/item>');
      final titleRegex = RegExp(r'<title>([\s\S]*?)<\/title>');
      final dateRegex = RegExp(r'<pubDate>([\s\S]*?)<\/pubDate>');
      
      final matches = itemRegex.allMatches(rss).take(4); // Top 4 articles
      
      if (matches.isEmpty) return 'No matching live news found.';

      final newsContext = StringBuffer();
      newsContext.writeln('LIVE NEWS SEARCH RESULTS:');
      
      int count = 1;
      for (final match in matches) {
        final itemBody = match.group(1) ?? '';
        final title = titleRegex.firstMatch(itemBody)?.group(1) ?? 'Unknown Title';
        final date = dateRegex.firstMatch(itemBody)?.group(1) ?? 'Unknown Date';
        
        // Strip out HTML entities (Google News puts CDATA or encoded HTML sometimes but usually title is clean)
        final cleanTitle = title.replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&apos;', "'").replaceAll('&lt;', '<').replaceAll('&gt;', '>');
        
        newsContext.writeln('$count. "$cleanTitle" (Published: $date)');
        count++;
      }
      
      print('[Veritas] Scraped ${count-1} live news articles.');
      return newsContext.toString();
    } catch (e) {
      print('[Veritas] News scrape failed: $e');
      return 'News scrape failed: $e';
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  INCEPTION MERCURY-2 — PRIMARY ANALYSIS ENGINE
  // ══════════════════════════════════════════════════════════════════════

  /// Calls Inception Labs Mercury-2 API directly from the phone.
  static Future<AnalysisResult> _analyzeViaInception(String text) async {
    try {
      // 1. Scrape live news first! (Provides up-to-date context since model ends in 2025)
      final newsContext = await _scrapeNews(text);
      
      // 2. Build the combined prompt
      final hindiDirective = LanguageProvider.instance.isHindi
          ? '\n\nIMPORTANT: The user speaks Hindi. Write the "ai_reasoning" field and "balanced_views" entries in Hindi (Devanagari script). Keep JSON keys in English.'
          : '';
      final combinedPrompt = 'CLAIM TO ANALYZE:\n"$text"\n\n$newsContext\n\n'
          'Remember: Prioritize the live news search results to determine if the claim is factual, misleading, or outright false. Give a precise credibility score.$hindiDirective';

      print('[Veritas] Calling Inception Mercury-2 with RAG context...');

      final response = await http.post(
        Uri.parse(_inceptionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_inceptionKey',
        },
        body: jsonEncode({
          'model': _inceptionModel,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': combinedPrompt},
          ],
          'response_format': {'type': 'json_object'},
          'max_tokens': 800,
          'temperature': 0.1,       // low temp = consistent, factual output
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        print('[Veritas] Inception API HTTP ${response.statusCode}: ${response.body}');
        throw Exception('Inception API error ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'] as String?;

      if (content == null || content.trim().isEmpty) {
        throw Exception('Inception returned empty content');
      }

      // Robust JSON extraction — handle markdown fences, extra text, etc.
      final json = _extractJson(content);
      print('[Veritas] Inception credibility: ${json['credibility']}');
      return _parseResult(json);

    } catch (e) {
      print('[Veritas] Inception failed ($e), falling back to local analysis');
      return _analyzeLocally(text);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  JSON EXTRACTION  (robust — handles markdown, extra text, etc.)
  // ══════════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _extractJson(String raw) {
    final trimmed = raw.trim();

    // 1. Try direct parse
    try { return jsonDecode(trimmed) as Map<String, dynamic>; } catch (_) {}

    // 2. Strip markdown code fences: ```json ... ```
    final fenceMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(trimmed);
    if (fenceMatch != null) {
      try { return jsonDecode(fenceMatch.group(1)!) as Map<String, dynamic>; } catch (_) {}
    }

    // 3. Extract first { ... } block
    final braceMatch = RegExp(r'\{[\s\S]*\}').firstMatch(trimmed);
    if (braceMatch != null) {
      try { return jsonDecode(braceMatch.group(0)!) as Map<String, dynamic>; } catch (_) {}
    }

    throw Exception('Could not parse JSON from Inception response: ${trimmed.substring(0, min(200, trimmed.length))}');
  }

  // ══════════════════════════════════════════════════════════════════════
  //  RESULT PARSER  (JSON → AnalysisResult)
  // ══════════════════════════════════════════════════════════════════════

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

  // ══════════════════════════════════════════════════════════════════════
  //  LOCAL NLP FALLBACK  (offline / API error)
  // ══════════════════════════════════════════════════════════════════════

  static const _clickbaitWords = [
    'shocking', 'unbelievable', 'you won\'t believe', 'mind-blowing',
    'jaw-dropping', 'insane', 'epic', 'must see', 'this will', 'omg',
    'what happened next', 'secret', 'they don\'t want you to know',
    'exposed', 'gone wrong', 'destroyed', 'slammed', 'blasted',
    'bombshell', 'breaking', 'just in', 'urgent', 'alert',
    'exclusive', 'leaked', 'banned', 'censored', 'cover-up',
  ];

  static const _manipulationWords = [
    'outrage', 'fury', 'terrifying', 'horrifying', 'disgusting',
    'heartbreaking', 'devastating', 'nightmare', 'catastrophe',
    'crisis', 'panic', 'emergency', 'threat', 'danger', 'warning',
    'scam', 'fraud', 'hoax', 'conspiracy', 'propaganda',
    'brainwash', 'lie', 'lies', 'fake', 'rigged', 'corrupt',
    'evil', 'traitor', 'enemy', 'destroy', 'attack',
  ];

  static const _fakeNewsPatterns = [
    'big pharma', 'mainstream media', 'deep state', 'new world order',
    'wake up sheeple', 'do your own research', 'they are hiding',
    'the truth about', 'what they don\'t tell you', 'exposed the truth',
    'government doesn\'t want', 'miracle cure', 'doctors hate',
    'one weird trick', '100% proven', 'scientifically proven',
    'share before deleted', 'share before removed', 'going viral',
  ];

  static const _credibilityWords = [
    'according to', 'study shows', 'research indicates', 'data suggests',
    'peer-reviewed', 'published in', 'university of', 'institute of',
    'official statement', 'spokesperson said', 'confirmed by',
    'evidence suggests', 'analysis shows', 'report finds',
    'statistics show', 'survey found', 'experts say',
    'investigation reveals', 'fact-check', 'verified',
  ];

  static const _leftBiasWords = [
    'progressive', 'equality', 'social justice', 'systemic',
    'marginalized', 'inclusivity', 'privilege', 'oppression',
  ];

  static const _rightBiasWords = [
    'traditional values', 'freedom', 'patriot', 'liberty',
    'constitution', 'second amendment', 'immigration crisis',
    'border security', 'law and order', 'woke',
  ];

  static AnalysisResult _analyzeLocally(String text) {
    final lower = text.toLowerCase();
    final words = lower.split(RegExp(r'\s+'));
    final wordCount = words.length;

    final clickbaitHits = _countMatches(lower, _clickbaitWords);
    final clickbaitScore = min(100.0, clickbaitHits * 18.0);
    final manipHits = _countMatches(lower, _manipulationWords);
    final manipIntensity = min(100.0, manipHits * 15.0);
    final manipLevel = manipIntensity > 60 ? 'HIGH' : manipIntensity > 30 ? 'MEDIUM' : 'LOW';
    final fakeHits = _countMatches(lower, _fakeNewsPatterns);
    final fakeScore = min(100.0, fakeHits * 25.0);
    final credHits = _countMatches(lower, _credibilityWords);
    final credBoost = min(40.0, credHits * 10.0);

    final leftHits = _countMatches(lower, _leftBiasWords);
    final rightHits = _countMatches(lower, _rightBiasWords);
    String biasLeaning = 'NEUTRAL';
    double biasConf = 20;
    if (leftHits > rightHits) { biasLeaning = 'LEFT'; biasConf = min(90.0, (leftHits - rightHits) * 20.0 + 30); }
    else if (rightHits > leftHits) { biasLeaning = 'RIGHT'; biasConf = min(90.0, (rightHits - leftHits) * 20.0 + 30); }

    final exclCount = '!'.allMatches(text).length;
    final capsRatio = wordCount > 0
        ? words.where((w) => w.length > 2 && w == w.toUpperCase()).length / wordCount : 0.0;
    final stylePenalty = min(25.0, exclCount * 5.0 + capsRatio * 40.0);

    double cred = 70.0 + credBoost - fakeScore * 0.6 - clickbaitScore * 0.3 - manipIntensity * 0.2 - stylePenalty;
    cred = max(5.0, min(95.0, cred));

    final foundKw = <String>[];
    for (final w in _manipulationWords) { if (lower.contains(w)) foundKw.add(w); }
    for (final w in _clickbaitWords) { if (lower.contains(w) && !foundKw.contains(w)) foundKw.add(w); }

    final parts = <String>['[Offline Analysis]'];
    if (cred >= 70) parts.add('Content appears credible.');
    else if (cred >= 40) parts.add('Mixed credibility signals.');
    else parts.add('Significant misinformation red flags.');
    if (fakeHits > 0) parts.add('$fakeHits misinformation pattern(s) detected.');
    if (clickbaitHits > 0) parts.add('$clickbaitHits clickbait indicator(s).');
    if (manipHits > 0) parts.add('$manipHits manipulation keyword(s).');
    if (wordCount < 20) parts.add('Very short text — limited analysis.');

    return AnalysisResult(
      credibility: cred,
      fakeProbability: max(5.0, min(95.0, 100 - cred)),
      manipulation: ManipulationData(level: manipLevel, emotion: _detectEmotion(lower), intensity: manipIntensity, keywords: foundKw.take(6).toList()),
      bias: BiasData(leaning: biasLeaning, confidence: biasConf, propagandaFlag: manipIntensity > 50 && fakeScore > 30),
      sourceReliability: SourceReliability(level: cred > 65 ? 'HIGH' : cred > 40 ? 'MEDIUM' : 'LOW', score: cred.toInt(), domain: 'offline analysis'),
      clickbait: ClickbaitData(isClickbait: clickbaitScore > 40, probability: clickbaitScore),
      balancedViews: cred < 50
          ? ['Cross-reference with established news sources before sharing.', 'Look for the same story from multiple independent outlets.']
          : ['Content follows standard reporting patterns.'],
      aiReasoning: parts.join(' '),
    );
  }

  static int _countMatches(String text, List<String> patterns) {
    int c = 0; for (final p in patterns) { if (text.contains(p)) c++; } return c;
  }

  static String _detectEmotion(String text) {
    final map = {
      'anger': ['outrage', 'fury', 'angry', 'rage', 'attack', 'destroy'],
      'fear': ['terrifying', 'horrifying', 'nightmare', 'threat', 'danger', 'panic'],
      'sadness': ['heartbreaking', 'devastating', 'tragic', 'loss', 'grief'],
      'surprise': ['shocking', 'unbelievable', 'jaw-dropping', 'bombshell'],
      'disgust': ['disgusting', 'sickening', 'appalling', 'shameful'],
    };
    String best = 'neutral'; int mx = 0;
    for (final e in map.entries) {
      int h = 0; for (final w in e.value) { if (text.contains(w)) h++; }
      if (h > mx) { mx = h; best = e.key; }
    }
    return best;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  UTILITY
  // ══════════════════════════════════════════════════════════════════════

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
