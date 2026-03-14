import 'package:flutter/material.dart';
import '../models/feed_models.dart';
import '../services/direct_analysis_service.dart';
import '../services/storage_service.dart';

class CreateBlogScreen extends StatefulWidget {
  const CreateBlogScreen({super.key});

  @override
  State<CreateBlogScreen> createState() => _CreateBlogScreenState();
}

class _CreateBlogScreenState extends State<CreateBlogScreen> {
  final TextEditingController _contentController = TextEditingController();
  bool _isFactChecking = false;

  Future<void> _factCheckAndPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isFactChecking = true);

    try {
      // 1. Analyze content using our main Inception pipeline
      final analysis = await DirectAnalysisService.analyzeText(content);

      // 2. Fetch User Profile Info (to act as the Author)
      final authorName = await StorageService.getUsername();

      // 3. Create BlogPost
      final post = BlogPost(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        author: authorName,
        content: content,
        analysis: analysis,
        comments: [], // Start with empty comments
      );

      // 4. Save to Storage
      await StorageService.saveBlogPost(post);

      if (!mounted) return;
      
      // Success feedback and return
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blog post published and fact-checked!')),
      );
      Navigator.pop(context, true); // true = indicates refresh needed

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isFactChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Blog Post', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All community posts are fact-checked by Veritas AI before publishing.',
                          style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: 'Share a news update, claim, or thought...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1D468B), width: 2),
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isFactChecking ? null : _factCheckAndPost,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Fact-Check & Publish', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D468B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          
          if (_isFactChecking)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing Context & Fact-Checking...',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
