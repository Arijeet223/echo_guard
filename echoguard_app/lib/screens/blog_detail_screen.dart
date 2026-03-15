import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
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
  late BlogPost? _liveBlog;

  @override
  void initState() {
    super.initState();
    _liveBlog = widget.item is BlogPost ? widget.item as BlogPost : null;
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _liveBlog == null) return;

    final author = await StorageService.getUsername();
    final comment = Comment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: author,
      text: text,
      timestamp: DateTime.now(),
    );

    await StorageService.addCommentToBlog(_liveBlog!.id, comment);
    await StorageService.loadBlogs();

    setState(() {
      _commentController.clear();
      _liveBlog!.comments.add(comment);
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _vote(String voteType) async {
    if (_liveBlog == null) return;
    await StorageService.voteBlog(_liveBlog!.id, voteType);

    // Refresh from cached data
    await StorageService.loadBlogs();
    final updated = StorageService.getBlogs().where((b) => b.id == _liveBlog!.id).firstOrNull;
    if (updated != null && mounted) {
      setState(() => _liveBlog = updated);
    } else if (mounted) {
      // For dummy blogs (not persisted), toggle locally
      setState(() {
        final old = _liveBlog!;
        final sameVote = old.userVote == voteType;
        int td = 0, fd = 0, md = 0;
        if (sameVote) {
          if (voteType == 'true') td = -1;
          if (voteType == 'false') fd = -1;
          if (voteType == 'misleading') md = -1;
        } else {
          if (old.userVote == 'true') td = -1;
          if (old.userVote == 'false') fd = -1;
          if (old.userVote == 'misleading') md = -1;
          if (voteType == 'true') td += 1;
          if (voteType == 'false') fd += 1;
          if (voteType == 'misleading') md += 1;
        }
        _liveBlog = BlogPost(
          id: old.id,
          timestamp: old.timestamp,
          author: old.author,
          content: old.content,
          analysis: old.analysis,
          comments: old.comments,
          votesTrue: old.votesTrue + td,
          votesFalse: old.votesFalse + fd,
          votesMisleading: old.votesMisleading + md,
          userVote: sameVote ? null : voteType,
        );
      });
    }
  }

  void _share() {
    String shareText;
    if (widget.item is NewsItem) {
      final news = widget.item as NewsItem;
      shareText = '📰 ${news.title}\nSource: ${news.source}\n🔗 ${news.url}\n\n— Shared via Veritas';
    } else {
      final blog = _liveBlog!;
      final scoreEmoji = blog.analysis.credibility >= 70 ? '✅' : blog.analysis.credibility >= 40 ? '⚠️' : '❌';
      shareText = '🔍 Veritas Community Post\n\n'
          '"${blog.content}"\n\n'
          '$scoreEmoji Echo Score: ${blog.analysis.credibility.toInt()}/100\n'
          '📊 Community: ${blog.votesTrue} True · ${blog.votesFalse} False · ${blog.votesMisleading} Misleading\n\n'
          '${blog.analysis.aiReasoning}\n\n'
          '— Verified by Veritas AI';
    }
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item is NewsItem) {
      return _buildNewsDetail(widget.item as NewsItem);
    } else {
      return _buildBlogDetail(_liveBlog!);
    }
  }

  Widget _buildNewsDetail(NewsItem news) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('News Article'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: _share),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black,
                  child: const Icon(Icons.public, color: Colors.black54),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(news.source, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      _formatDate(news.timestamp),
                      style: TextStyle(color: Colors.black, fontSize: 12),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
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
                    'This is an external news headline. To check its credibility, copy the link and paste it into the Veritas Input Analyzer.',
                    style: TextStyle(color: Color(0xFFCD853F), fontSize: 13, height: 1.4),
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

    Color badgeColor = isTrue ? const Color(0xFF0D9488) : isMisleading ? Color(0xFFCD853F) : Color(0xFF8B0000);
    String badgeText = isTrue ? 'VERIFIED CONTEXT' : isMisleading ? 'MISLEADING CONTEXT' : 'FALSE CONTEXT';

    return Scaffold(
      backgroundColor: Color(0xFFD7C9B8),
      appBar: AppBar(
        title: const Text('Community Post'),
        backgroundColor: Color(0xFFD7C9B8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: _share),
        ],
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
                            backgroundColor: Colors.black,
                            child: const Icon(Icons.person, color: Colors.black),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(blog.author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                _formatDate(blog.timestamp),
                                style: TextStyle(color: Colors.black, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                      color: const Color(0xFFFFF9E6),
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
                          style: TextStyle(color: Colors.black, fontSize: 14, height: 1.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Voting Section ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Community Verdict', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _voteChip(
                              icon: Icons.check_circle_rounded,
                              label: 'True',
                              count: blog.votesTrue,
                              color: const Color(0xFF556B2F),
                              isSelected: blog.userVote == 'true',
                              onTap: () => _vote('true'),
                            ),
                            const SizedBox(width: 10),
                            _voteChip(
                              icon: Icons.cancel_rounded,
                              label: 'False',
                              count: blog.votesFalse,
                              color: Color(0xFF8B0000),
                              isSelected: blog.userVote == 'false',
                              onTap: () => _vote('false'),
                            ),
                            const SizedBox(width: 10),
                            _voteChip(
                              icon: Icons.warning_rounded,
                              label: 'Misleading',
                              count: blog.votesMisleading,
                              color: Color(0xFFCD853F),
                              isSelected: blog.userVote == 'misleading',
                              onTap: () => _vote('misleading'),
                            ),
                          ],
                        ),
                        if (blog.totalVotes > 0) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 6,
                              child: Row(
                                children: [
                                  if (blog.votesTrue > 0)
                                    Expanded(flex: blog.votesTrue, child: Container(color: const Color(0xFF556B2F))),
                                  if (blog.votesFalse > 0)
                                    Expanded(flex: blog.votesFalse, child: Container(color: Color(0xFF8B0000))),
                                  if (blog.votesMisleading > 0)
                                    Expanded(flex: blog.votesMisleading, child: Container(color: Color(0xFFCD853F))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Comments (${blog.comments.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  if (blog.comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No comments yet. Be the first!', style: TextStyle(color: Colors.black)),
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
                                  Text(_formatDate(c.timestamp), style: TextStyle(color: Colors.black, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(c.text, style: TextStyle(color: Colors.black, fontSize: 14)),
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
              color: Color(0xFFD7C9B8),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2), blurRadius: 4)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.black54),
                      filled: true,
                      fillColor: Colors.white,
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
                      color: Color(0xFF4A342A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Color(0xFFD7C9B8), size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _voteChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Color(0xFFD7C9B8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : Colors.black, width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? color : Colors.black)),
              Text(label, style: TextStyle(fontSize: 10, color: isSelected ? color : Colors.black)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
