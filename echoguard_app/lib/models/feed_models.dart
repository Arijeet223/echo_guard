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
  int votesTrue;
  int votesFalse;
  int votesMisleading;
  String? userVote; // 'true', 'false', 'misleading', or null

  BlogPost({
    required String id,
    required DateTime timestamp,
    required this.author,
    required this.content,
    required this.analysis,
    this.comments = const [],
    this.votesTrue = 0,
    this.votesFalse = 0,
    this.votesMisleading = 0,
    this.userVote,
  }) : super(id: id, timestamp: timestamp);

  int get totalVotes => votesTrue + votesFalse + votesMisleading;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'author': author,
      'content': content,
      'analysis': analysis.toJson(),
      'comments': comments.map((c) => c.toJson()).toList(),
      'votesTrue': votesTrue,
      'votesFalse': votesFalse,
      'votesMisleading': votesMisleading,
      'userVote': userVote,
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
      votesTrue: json['votesTrue'] ?? 0,
      votesFalse: json['votesFalse'] ?? 0,
      votesMisleading: json['votesMisleading'] ?? 0,
      userVote: json['userVote'] as String?,
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
