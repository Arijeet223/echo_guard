import 'dart:convert';
import '../models/analysis_result.dart';

abstract class FeedItem {
  final String id;
  final DateTime timestamp;

  FeedItem({required this.id, required this.timestamp});
}

class NewsItem extends FeedItem {
  final String title;
  final String source;
  final String url;
  final String description;

  NewsItem({
    required String id,
    required DateTime timestamp,
    required this.title,
    required this.source,
    required this.url,
    required this.description,
  }) : super(id: id, timestamp: timestamp);
}

class BlogPost extends FeedItem {
  final String author;
  final String content;
  final AnalysisResult analysis;
  final List<Comment> comments;

  BlogPost({
    required String id,
    required DateTime timestamp,
    required this.author,
    required this.content,
    required this.analysis,
    this.comments = const [],
  }) : super(id: id, timestamp: timestamp);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'author': author,
      'content': content,
      'analysis': {
        'credibility': analysis.credibility,
        'fake_probability': analysis.fakeProbability,
        'manipulation': {
          'level': analysis.manipulation.level,
          'emotion': analysis.manipulation.emotion,
          'intensity': analysis.manipulation.intensity,
          'keywords': analysis.manipulation.keywords,
        },
        'bias': {
          'leaning': analysis.bias.leaning,
          'confidence': analysis.bias.confidence,
          'propaganda_flag': analysis.bias.propagandaFlag,
        },
        'source_reliability': {
          'level': analysis.sourceReliability.level,
          'score': analysis.sourceReliability.score,
          'domain': analysis.sourceReliability.domain,
        },
        'clickbait': {
          'is_clickbait': analysis.clickbait.isClickbait,
          'probability': analysis.clickbait.probability,
        },
        'balanced_views': analysis.balancedViews,
        'ai_reasoning': analysis.aiReasoning,
      },
      'comments': comments.map((c) => c.toJson()).toList(),
    };
  }

  factory BlogPost.fromJson(Map<String, dynamic> json) {
    final analysisJson = json['analysis'] as Map<String, dynamic>;
    return BlogPost(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      author: json['author'],
      content: json['content'],
      analysis: AnalysisResult.fromJson(analysisJson),
      comments: (json['comments'] as List<dynamic>?)
              ?.map((c) => Comment.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Comment {
  final String id;
  final String author;
  final String text;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.author,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      author: json['author'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
