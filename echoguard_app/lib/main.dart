import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/theme_provider.dart';
import 'services/language_provider.dart';
import 'services/app_strings.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/avatar_widget.dart';

void main() {
  runApp(const VeritasApp());
}

class VeritasApp extends StatefulWidget {
  const VeritasApp({super.key});

  // Global access to theme provider
  static final ThemeProvider themeProvider = ThemeProvider();

  @override
  State<VeritasApp> createState() => _VeritasAppState();
}

class _VeritasAppState extends State<VeritasApp> {
  @override
  void initState() {
    super.initState();
    VeritasApp.themeProvider.addListener(() => setState(() {}));
    LanguageProvider.instance.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = VeritasApp.themeProvider.isDark;
    return MaterialApp(
      title: 'Veritas',
      debugShowCheckedModeBanner: false,
      theme: ThemeProvider.lightTheme.copyWith(
        textTheme: GoogleFonts.interTextTheme(ThemeProvider.lightTheme.textTheme),
      ),
      darkTheme: ThemeProvider.darkTheme.copyWith(
        textTheme: GoogleFonts.interTextTheme(ThemeProvider.darkTheme.textTheme),
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const MainNavigation(),
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            const AvatarWidget(),
          ],
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ChatbotScreen(),
    const ScanScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Color(0xFFD7C9B8),
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: isDark ? Colors.white70 : Colors.black,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.3),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, letterSpacing: -0.3),
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: S.get('home')),
            BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: S.get('mira')),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: S.get('scan')),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: S.get('history')),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: S.get('profile')),
          ],
        ),
      ),
    );
  }
}
