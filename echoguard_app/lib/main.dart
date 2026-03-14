import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  runApp(const EchoGuardApp());
}

class EchoGuardApp extends StatefulWidget {
  const EchoGuardApp({super.key});

  // Global access to theme provider
  static final ThemeProvider themeProvider = ThemeProvider();

  @override
  State<EchoGuardApp> createState() => _EchoGuardAppState();
}

class _EchoGuardAppState extends State<EchoGuardApp> {
  @override
  void initState() {
    super.initState();
    EchoGuardApp.themeProvider.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = EchoGuardApp.themeProvider.isDark;
    return MaterialApp(
      title: 'EchoGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeProvider.lightTheme.copyWith(
        textTheme: GoogleFonts.interTextTheme(ThemeProvider.lightTheme.textTheme),
      ),
      darkTheme: ThemeProvider.darkTheme.copyWith(
        textTheme: GoogleFonts.interTextTheme(ThemeProvider.darkTheme.textTheme),
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const MainNavigation(),
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
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: Colors.grey.shade500,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.3),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, letterSpacing: -0.3),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'HOME'),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'SCAN'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'HISTORY'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'PROFILE'),
          ],
        ),
      ),
    );
  }
}
