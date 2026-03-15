import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════
//  LanguageProvider — Singleton for Hindi/English toggle
// ═══════════════════════════════════════════════════════════════════════

class LanguageProvider extends ChangeNotifier {
  static const String _key = 'eg_language';
  String _language = 'en'; // 'en' or 'hi'

  String get language => _language;
  bool get isHindi => _language == 'hi';

  // Singleton
  static final LanguageProvider _instance = LanguageProvider._();
  static LanguageProvider get instance => _instance;
  LanguageProvider._() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString(_key) ?? 'en';
    notifyListeners();
  }

  Future<void> toggle() async {
    _language = _language == 'en' ? 'hi' : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _language);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _language);
    notifyListeners();
  }
}
