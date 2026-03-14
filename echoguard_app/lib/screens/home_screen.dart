import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'analysis_screen.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _hasUnreadNotifications = true;

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color)),
                    TextButton(
                      onPressed: () {
                        setState(() => _hasUnreadNotifications = false);
                        Navigator.pop(context);
                      },
                      child: Text('Mark all as read', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _notificationItem(
                      title: 'High Risk Alert',
                      body: 'A recent claim you scanned has been flagged as severe misinformation.',
                      time: '2 mins ago',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red,
                      isUnread: _hasUnreadNotifications,
                    ),
                    _notificationItem(
                      title: 'Weekly Summary Ready',
                      body: 'You scanned 14 articles this week. 8 were verified as truthful.',
                      time: '1 day ago',
                      icon: Icons.analytics_outlined,
                      color: theme.colorScheme.primary,
                      isUnread: false,
                    ),
                    _notificationItem(
                      title: 'System Update',
                      body: 'EchoGuard AI models have been updated successfully.',
                      time: '3 days ago',
                      icon: Icons.system_update_alt,
                      color: Colors.grey.shade600,
                      isUnread: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _notificationItem({required String title, required String body, required String time, required IconData icon, required Color color, required bool isUnread}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnread ? color.withOpacity(0.05) : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUnread ? color.withOpacity(0.3) : theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color)),
                    Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 800, maxHeight: 800);
    
    if (image == null) return;
    
    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);
      final result = await ApiService.analyzeImage(base64Str);
      
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnalysisScreen(text: '[Image Analysis]')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image analysis failed: $e')),
      );
    }
  }

  void _openUrlDialog() {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link, color: Color(0xFF1D468B)),
            SizedBox(width: 8),
            Text('Analyze URL'),
          ],
        ),
        content: TextField(
          controller: urlController,
          decoration: InputDecoration(
            hintText: 'https://example.com/article',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.language),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(ctx);
              // Add https:// if missing
              final finalUrl = url.startsWith('http') ? url : 'https://$url';
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AnalysisScreen(text: finalUrl)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D468B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
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
            Text('EchoGuard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.appBarTheme.foregroundColor)),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(icon: Icon(Icons.notifications_outlined, color: Colors.grey.shade600), onPressed: () => _showNotifications(context)),
              if (_hasUnreadNotifications)
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
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
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
                        fillColor: theme.scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1D468B))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: _iconButton(Icons.image_outlined),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _openUrlDialog,
                              child: _iconButton(Icons.link),
                            ),
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
                  Text('Trending Claims', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color)),
                  TextButton(onPressed: () {}, child: Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary))),
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
    return Builder(builder: (context) {
      final theme = Theme.of(context);
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Icon(icon, size: 16, color: Colors.grey.shade600),
      );
    });
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
    return Builder(builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
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
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.dividerColor))),
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
    });
  }
}

