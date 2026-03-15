import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _key = 'eg_dark_mode';
  bool _isDark = false;

  bool get isDark => _isDark;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDark);
    notifyListeners();
  }

  // ===== LIGHT THEME =====
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A342A),
      primary: const Color(0xFF4A342A),
      surface: Color(0xFFD7C9B8),
    ),
    scaffoldBackgroundColor: const Color(0xFFD7C9B8),
    cardColor: Color(0xFFD7C9B8),
    dividerColor: const Color(0xFFF1EEE9),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFD7C9B8),
      surfaceTintColor: Colors.transparent,
      foregroundColor: Color(0xFF0F172A),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFD7C9B8),
      selectedItemColor: Color(0xFF4A342A),
      unselectedItemColor: Colors.black,
    ),
    useMaterial3: true,
  );

  // ===== DARK THEME =====
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A90D9),
      brightness: Brightness.dark,
      primary: const Color(0xFF4A90D9),
      surface: const Color(0xFF1A1A2E),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0F1A),
    cardColor: const Color(0xFF1A1A2E),
    dividerColor: const Color(0xFF2A2A3E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F0F1A),
      surfaceTintColor: Colors.transparent,
      foregroundColor: Color(0xFFD7C9B8),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1A1A2E),
      selectedItemColor: Color(0xFF4A90D9),
      unselectedItemColor: Colors.black,
    ),
    useMaterial3: true,
  );
}
