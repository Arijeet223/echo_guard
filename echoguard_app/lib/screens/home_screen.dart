import 'package:flutter/material.dart';
import 'analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();

  void _analyze() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste some text or a link to analyze.')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisScreen(text: text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFBF7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFF1D468B), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.security, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            const Text('EchoGuard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(icon: Icon(Icons.notifications_outlined, color: Colors.grey.shade600), onPressed: () {}),
              Positioned(top: 12, right: 12, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input Analyzer Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1EEE9)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics_outlined, color: const Color(0xFF0D9488), size: 18),
                        const SizedBox(width: 8),
                        Text('INPUT ANALYZER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Paste text, link, or claim to analyze...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFFDFBF7),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF1EEE9))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF1EEE9))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1D468B))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _iconButton(Icons.image_outlined),
                            const SizedBox(width: 6),
                            _iconButton(Icons.link),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _analyze,
                          icon: const Text('Analyze', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          label: const Icon(Icons.send, size: 16),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D468B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Trending Claims
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Trending Claims', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  TextButton(onPressed: () {}, child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            _trendingCard(
              title: 'New health regulation bans specific vegetable imports starting next month',
              score: 14,
              verdict: 'False',
              badgeColor: Colors.red,
              scoreColor: Colors.red,
              icon: Icons.error,
              iconBgColor: Colors.red.shade50,
            ),
            const SizedBox(height: 16),
            _trendingCard(
              title: 'Global internet traffic reaches record high during international event',
              score: 98,
              verdict: 'Verified',
              badgeColor: const Color(0xFF0D9488),
              scoreColor: const Color(0xFF0D9488),
              icon: Icons.check_circle,
              iconBgColor: const Color(0xFFE0F7F5),
            ),
            const SizedBox(height: 16),
            _trendingCard(
              title: 'Major tech company announces full remote work policy for all staff',
              score: 45,
              verdict: 'Misleading',
              badgeColor: Colors.amber.shade700,
              scoreColor: Colors.amber.shade700,
              icon: Icons.warning_rounded,
              iconBgColor: Colors.yellow.shade50,
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1EEE9)),
      ),
      child: Icon(icon, size: 16, color: Colors.grey.shade600),
    );
  }

  Widget _trendingCard({
    required String title,
    required int score,
    required String verdict,
    required Color badgeColor,
    required Color scoreColor,
    required IconData icon,
    required Color iconBgColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1EEE9)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                gradient: LinearGradient(
                  colors: [badgeColor.withOpacity(0.1), badgeColor.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Center(child: Icon(Icons.article_outlined, size: 48, color: badgeColor.withOpacity(0.3))),
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)),
                      child: Text(verdict, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.3)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1EEE9)))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ECHO SCORE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: -0.3, color: Colors.grey.shade400)),
                            Text('$score/100', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scoreColor)),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(icon: Icon(Icons.share, color: Colors.grey.shade400), onPressed: () {}),
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: iconBgColor),
                              child: Icon(icon, color: scoreColor, size: 22),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
