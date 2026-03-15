import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'analysis_screen.dart';
import 'create_blog_screen.dart';
import 'blog_detail_screen.dart';
import 'notification_screen.dart';
import '../models/feed_models.dart';
import '../services/api_service.dart';
import '../services/feed_service.dart';
import '../services/language_provider.dart';
import '../services/app_strings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _hasUnreadNotifications = true;
  late Future<List<FeedItem>> _feedFuture;

  @override
  void initState() {
    super.initState();
    _refreshFeed();
    LanguageProvider.instance.addListener(_onLangChange);
  }

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChange);
    super.dispose();
  }

  void _refreshFeed() {
    setState(() {
      _feedFuture = FeedService.getUnifiedFeed();
    });
  }


  void _analyze() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.get('no_text_error'))),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisScreen(text: text)));
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 40, maxWidth: 800, maxHeight: 800);

    if (image == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: Text(S.get('extracting'), style: TextStyle(color: Color(0xFFD7C9B8))),
            ),
          ],
        ),
      ),
    );

    try {
      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);
      final result = await ApiService.analyzeImage(base64Str);

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisScreen(
            text: result.extractedText?.isNotEmpty == true
                ? result.extractedText!
                : '[Image Analysis]',
            preloadedResult: result,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${S.get('image_fail')}: $e')),
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
            Icon(Icons.link, color: Color(0xFF4A342A)),
            SizedBox(width: 8),
            Text('Analyze URL'),
          ],
        ),
        content: TextField(
          controller: urlController,
          decoration: InputDecoration(
            hintText: 'https://example.com/article',
            hintStyle: TextStyle(color: Colors.black),
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
              backgroundColor: const Color(0xFF4A342A),
              foregroundColor: Color(0xFFD7C9B8),
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
              decoration: BoxDecoration(color: const Color(0xFF4A342A), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.security, color: Color(0xFFD7C9B8), size: 20),
            ),
            const SizedBox(width: 8),
            Text(S.get('app_title'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.appBarTheme.foregroundColor)),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: Colors.black), 
                onPressed: () {
                  setState(() => _hasUnreadNotifications = false);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                },
              ),
              if (_hasUnreadNotifications)
                Positioned(top: 12, right: 12, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF8B0000), shape: BoxShape.circle))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateBlogScreen()),
          );
          if (result == true) {
            _refreshFeed();
          }
        },
        backgroundColor: const Color(0xFF4A342A),
        foregroundColor: Color(0xFFD7C9B8),
        icon: const Icon(Icons.edit),
        label: Text(S.get('create_post')),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshFeed(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80), // Fab space
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
                          Text('INPUT ANALYZER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1, color: Colors.black)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controller,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: S.get('paste_text'),
                          hintStyle: TextStyle(color: Colors.black, fontSize: 14),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4A342A))),
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
                            icon: Text(S.get('analyze'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            label: const Icon(Icons.send, size: 16),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A342A),
                              foregroundColor: Color(0xFFD7C9B8),
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

              // Dynamic Feed Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Live Feed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color)),
                    TextButton(onPressed: _refreshFeed, child: Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary))),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Dynamic Feed Content
              FutureBuilder<List<FeedItem>>(
                future: _feedFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(child: Text('Error loading feed: ${snapshot.error}')),
                    );
                  }
                  
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('No posts yet.')),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      if (item is NewsItem) {
                        return _buildNewsCard(item);
                      } else if (item is BlogPost) {
                        return _buildBlogCard(item);
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
            ],
          ),
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
        child: Icon(icon, size: 16, color: Colors.black),
      );
    });
  }

  Widget _buildNewsCard(NewsItem news) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => BlogDetailScreen(item: news)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // News Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.public, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(news.source, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Share.share('📰 ${news.title}\nSource: ${news.source}\n🔗 ${news.url}\n\n— Shared via Veritas');
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.share_outlined, size: 16, color: Colors.blue.shade300),
                      ),
                    ),
                    Text('Live News', style: TextStyle(fontSize: 10, color: Colors.black)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(news.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.3)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Tap to read more', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 10, color: theme.colorScheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlogCard(BlogPost blog) {
    final theme = Theme.of(context);
    final score = blog.analysis.credibility.toInt();
    
    bool isMisleading = score >= 40 && score < 70;
    bool isFalse = score < 40;
    bool isTrue = score >= 70;

    Color badgeColor = isTrue ? const Color(0xFF0D9488) : isMisleading ? Color(0xFFCD853F) : Color(0xFF8B0000);
    String badgeText = isTrue ? 'Verified' : isMisleading ? 'Misleading' : 'False';
    IconData icon = isTrue ? Icons.check_circle : isMisleading ? Icons.warning_rounded : Icons.error;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => BlogDetailScreen(item: blog)));
      },
      child: Padding(
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
                height: 80,
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
                    Positioned(
                      top: 12, left: 16,
                      child: Row(
                        children: [
                          CircleAvatar(radius: 12, backgroundColor: Color(0xFFD7C9B8), child: Icon(Icons.person, size: 14, color: Colors.black)),
                          const SizedBox(width: 8),
                          Text(blog.author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)),
                        child: Text(badgeText, style: const TextStyle(color: Color(0xFFD7C9B8), fontSize: 10, fontWeight: FontWeight.bold)),
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
                    Text(
                      blog.content.length > 100 ? '${blog.content.substring(0, 100)}...' : blog.content,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.3),
                    ),
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
                              Text('ECHO SCORE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: -0.3, color: Colors.black)),
                              Text('$score/100', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: badgeColor)),
                            ],
                          ),
                          Row(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.how_to_vote_outlined, size: 16, color: Colors.black),
                                  const SizedBox(width: 4),
                                  Text('${blog.totalVotes}', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Row(
                                children: [
                                  Icon(Icons.chat_bubble_outline, size: 16, color: Colors.black),
                                  const SizedBox(width: 4),
                                  Text('${blog.comments.length}', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: badgeColor.withOpacity(0.1)),
                                child: Icon(icon, color: badgeColor, size: 18),
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
      ),
    );
  }
}

