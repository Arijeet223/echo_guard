import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryItem {
  final int id;
  final String text;
  final String date;
  final double score;
  final String verdict;

  HistoryItem({
    required this.id,
    required this.text,
    required this.date,
    required this.score,
    required this.verdict,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'date': date,
    'score': score,
    'verdict': verdict,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] ?? 0,
      text: json['text'] ?? '',
      date: json['date'] ?? '',
      score: (json['score'] as num).toDouble(),
      verdict: json['verdict'] ?? 'Unknown',
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

  static Future<void> addToHistory(String text, double score) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();

    String verdict = 'High Risk';
    if (score >= 70) {
      verdict = 'Verified';
    } else if (score >= 40) {
      verdict = 'Misleading';
    }

    final item = HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch,
      text: text.length > 50 ? '${text.substring(0, 50)}...' : text,
      date: DateTime.now().toString(),
      score: score,
      verdict: verdict,
    );

    history.insert(0, item);
    if (history.length > 20) history.removeRange(20, history.length);

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
}
