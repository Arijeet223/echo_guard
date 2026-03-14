import 'package:flutter/material.dart';
import '../models/feed_models.dart';
import '../services/storage_service.dart';

class BlogDetailScreen extends StatefulWidget {
  final FeedItem item;

  const BlogDetailScreen({super.key, required this.item});

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  final TextEditingController _commentController = TextEditingController();

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (widget.item is BlogPost) {
      final blog = widget.item as BlogPost;
      final author = await StorageService.getUsername();
      
      final comment = Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        author: author,
        text: text,
        timestamp: DateTime.now(),
      );

      await StorageService.addCommentToBlog(blog.id, comment);
      await StorageService.loadBlogs();

      setState(() {
        _commentController.clear();
        // Since the blog instances are immutable clones, we need to refresh the reference
        // Actually for simplicity we can just mutate the array in UI, or trigger a rebuild via FutureBuilder
        blog.comments.add(comment);
      });
      // dismiss keyboard
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item is NewsItem) {
      return _buildNewsDetail(widget.item as NewsItem);
    } else {
      return _buildBlogDetail(widget.item as BlogPost);
    }
  }

  Widget _buildNewsDetail(NewsItem news) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('News Article'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: const Icon(Icons.public, color: Colors.black54),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(news.source, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      _formatDate(news.timestamp),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              news.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3),
            ),
            const SizedBox(height: 24),
            // Fake warning for external news (since we aren't analyzing RSS yet directly on ingestion)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6), // Light yellow
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFECCC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFFEAB308), size: 18),
                      SizedBox(width: 8),
                      Text('Veritas Notice', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD97706), fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is an external news headline. To check its credibility, copy the link and paste it into the EchoGuard Input Analyzer.',
                    style: TextStyle(color: Colors.orange.shade900, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlogDetail(BlogPost blog) {
    bool isMisleading = blog.analysis.credibility >= 40 && blog.analysis.credibility < 70;
    bool isFalse = blog.analysis.credibility < 40;
    bool isTrue = blog.analysis.credibility >= 70;

    Color badgeColor = isTrue ? const Color(0xFF0D9488) : isMisleading ? Colors.amber.shade700 : Colors.red;
    String badgeText = isTrue ? 'VERIFIED CONTEXT' : isMisleading ? 'MISLEADING CONTEXT' : 'FALSE CONTEXT';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Community Post'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey.shade200,
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(blog.author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                _formatDate(blog.timestamp),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.share, color: Colors.grey.shade400, size: 20),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    blog.content,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3),
                  ),
                  const SizedBox(height: 24),

                  // Echo Score Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6), // Reference yellowish
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFECCC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.auto_awesome, color: Color(0xFFEAB308), size: 18),
                                SizedBox(width: 8),
                                Text('Veritas Analysis', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD97706), fontSize: 16)),
                              ],
                            ),
                            Text('${blog.analysis.credibility.toInt()}/100', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          blog.analysis.aiReasoning.isNotEmpty ? blog.analysis.aiReasoning : 'Credibility score: ${blog.analysis.credibility.toInt()}/100. Bias: ${blog.analysis.bias.leaning}.',
                          style: TextStyle(color: Colors.grey.shade800, fontSize: 14, height: 1.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  if (blog.comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No comments yet. Be the first!', style: TextStyle(color: Colors.grey.shade500)),
                      ),
                    ),
                    
                  ...blog.comments.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(c.author[0].toUpperCase(), style: const TextStyle(color: Colors.blue, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(c.author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 8),
                                  Text(_formatDate(c.timestamp), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(c.text, style: TextStyle(color: Colors.grey.shade800, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          
          // Comment Input Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2), blurRadius: 4)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _postComment,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1D468B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
