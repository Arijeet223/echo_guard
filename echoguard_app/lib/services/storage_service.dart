import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feed_models.dart';

class HistoryItem {
  final int id;
  final String text;
  final String fullText;
  final String date;
  final double score;
  final String verdict;
  final Map<String, dynamic>? resultJson;

  HistoryItem({
    required this.id,
    required this.text,
    this.fullText = '',
    required this.date,
    required this.score,
    required this.verdict,
    this.resultJson,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'fullText': fullText,
    'date': date,
    'score': score,
    'verdict': verdict,
    if (resultJson != null) 'resultJson': resultJson,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] ?? 0,
      text: json['text'] ?? '',
      fullText: json['fullText'] ?? '',
      date: json['date'] ?? '',
      score: (json['score'] as num).toDouble(),
      verdict: json['verdict'] ?? 'Unknown',
      resultJson: json['resultJson'] as Map<String, dynamic>?,
    );
  }
}

class StorageService {
  static Future<List<HistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('eg_history') ?? '[]';
    final list = jsonDecode(data) as List;
    return list.map((e) => HistoryItem.fromJson(e)).toList();
  }

  static Future<void> addToHistory(String text, double score, {Map<String, dynamic>? resultJson}) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();

    // Dedup: skip if the same text+score was saved in the last 10 seconds
    final now = DateTime.now().millisecondsSinceEpoch;
    final truncatedText = text.length > 50 ? '${text.substring(0, 50)}...' : text;
    final isDuplicate = history.isNotEmpty &&
        (now - history.first.id) < 10000 &&
        history.first.text == truncatedText &&
        (history.first.score - score).abs() < 1;
    if (isDuplicate) return;

    String verdict = 'High Risk';
    if (score >= 70) {
      verdict = 'Verified';
    } else if (score >= 40) {
      verdict = 'Misleading';
    }

    final item = HistoryItem(
      id: now,
      text: truncatedText,
      fullText: text,
      date: DateTime.now().toString(),
      score: score,
      verdict: verdict,
      resultJson: resultJson,
    );

    history.insert(0, item);
    if (history.length > 50) history.removeRange(50, history.length);

    await prefs.setString(
      'eg_history',
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('eg_history');
  }

  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('eg_username') ?? '@EchoGuard_User';
  }

  static Future<void> setUsername(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eg_username', name);
  }

  static Future<String> getBio() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('eg_bio') ?? 'Passionate about digital truth and combating misinformation.';
  }

  static Future<void> setBio(String bio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eg_bio', bio);
  }

  // ────────────────────────────────────────────────────────────────────────
  // BLOG POSTS (Community Feed)
  // ────────────────────────────────────────────────────────────────────────
  static const String _blogsKey = 'echoguard_blogs';
  static List<BlogPost> _cachedBlogs = [];

  static Future<void> loadBlogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? blogsJson = prefs.getString(_blogsKey);

      if (blogsJson != null) {
        final List<dynamic> decoded = jsonDecode(blogsJson);
        _cachedBlogs = decoded.map((e) => BlogPost.fromJson(e as Map<String, dynamic>)).toList();
        
        // Sort descending by timestamp
        _cachedBlogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) {
      // Print safely without depending on flutter/foundation.dart in this block
      print('Error loading blogs: $e');
    }
  }

  static List<BlogPost> getBlogs() => List.unmodifiable(_cachedBlogs);

  static Future<void> saveBlogPost(BlogPost post) async {
    _cachedBlogs.insert(0, post); // Add to top
    await _persistBlogs();
  }

  static Future<void> addCommentToBlog(String blogId, Comment comment) async {
    final index = _cachedBlogs.indexWhere((b) => b.id == blogId);
    if (index != -1) {
      final oldBlog = _cachedBlogs[index];
      final newComments = List<Comment>.from(oldBlog.comments)..add(comment);
      
      final updatedBlog = BlogPost(
        id: oldBlog.id,
        timestamp: oldBlog.timestamp,
        author: oldBlog.author,
        content: oldBlog.content,
        analysis: oldBlog.analysis,
        comments: newComments,
      );
      
      _cachedBlogs[index] = updatedBlog;
      await _persistBlogs();
    }
  }

  static Future<void> _persistBlogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList = 
          _cachedBlogs.map((b) => b.toJson()).toList();
      await prefs.setString(_blogsKey, jsonEncode(jsonList));
    } catch (e) {
      print('Error saving blogs: $e');
    }
  }
}
