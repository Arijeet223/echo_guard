class AnalysisResult {
  final double credibility;
  final double fakeProbability;
  final ManipulationData manipulation;
  final BiasData bias;
  final SourceReliability sourceReliability;
  final ClickbaitData clickbait;
  final List<String> balancedViews;
  final String aiReasoning;
  final String? extractedText;  // populated for image/URL analysis

  AnalysisResult({
    required this.credibility,
    required this.fakeProbability,
    required this.manipulation,
    required this.bias,
    required this.sourceReliability,
    required this.clickbait,
    required this.balancedViews,
    required this.aiReasoning,
    this.extractedText,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      credibility: (json['credibility'] as num).toDouble(),
      fakeProbability: (json['fake_probability'] as num).toDouble(),
      manipulation: ManipulationData.fromJson(json['manipulation']),
      bias: BiasData.fromJson(json['bias']),
      sourceReliability: SourceReliability.fromJson(json['source_reliability']),
      clickbait: ClickbaitData.fromJson(json['clickbait']),
      balancedViews: List<String>.from(json['balanced_views'] ?? []),
      aiReasoning: json['ai_reasoning'] ?? '',
      extractedText: json['extracted_text'] as String?,
    );
  }
}

class ManipulationData {
  final String level;
  final String emotion;
  final double intensity;
  final List<String> keywords;

  ManipulationData({
    required this.level,
    required this.emotion,
    required this.intensity,
    required this.keywords,
  });

  factory ManipulationData.fromJson(Map<String, dynamic> json) {
    return ManipulationData(
      level: json['level'] ?? 'LOW',
      emotion: json['emotion'] ?? 'neutral',
      intensity: (json['intensity'] as num).toDouble(),
      keywords: List<String>.from(json['keywords'] ?? []),
    );
  }
}

class BiasData {
  final String leaning;
  final double confidence;
  final bool propagandaFlag;

  BiasData({
    required this.leaning,
    required this.confidence,
    required this.propagandaFlag,
  });

  factory BiasData.fromJson(Map<String, dynamic> json) {
    return BiasData(
      leaning: json['leaning'] ?? 'NEUTRAL',
      confidence: (json['confidence'] as num).toDouble(),
      propagandaFlag: json['propaganda_flag'] ?? false,
    );
  }
}

class SourceReliability {
  final String level;
  final int score;
  final String domain;

  SourceReliability({
    required this.level,
    required this.score,
    required this.domain,
  });

  factory SourceReliability.fromJson(Map<String, dynamic> json) {
    return SourceReliability(
      level: json['level'] ?? 'LOW',
      score: json['score'] ?? 0,
      domain: json['domain'] ?? 'unknown',
    );
  }
}

class ClickbaitData {
  final bool isClickbait;
  final double probability;

  ClickbaitData({
    required this.isClickbait,
    required this.probability,
  });

  factory ClickbaitData.fromJson(Map<String, dynamic> json) {
    return ClickbaitData(
      isClickbait: json['is_clickbait'] ?? false,
      probability: (json['probability'] as num).toDouble(),
    );
  }
}
