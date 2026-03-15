import 'package:flutter/material.dart';
import '../services/direct_analysis_service.dart';
import '../services/storage_service.dart';
import '../models/analysis_result.dart';
import '../models/feed_models.dart';
import '../services/feed_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final AnalysisResult? analysisResult;

  ChatMessage({required this.text, required this.isUser, this.analysisResult});
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Initial greeting
    _messages.add(ChatMessage(
      text: 'Hello! I am Mira, your Veritas AI assistant. Ask me to fact-check any claim, news, or rumor!',
      isUser: false,
    ));
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });
    _msgController.clear();
    _scrollToBottom();

    final lower = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (lower == 'hi' || lower == 'hello' || lower == 'hey' || lower == 'hie') {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(text: 'Hello! How can I help you today?', isUser: false));
      });
      _scrollToBottom();
      return;
    }

    if (lower.contains('news') || lower.contains('latest news') || lower.contains('popular news')) {
      try {
        final feed = await FeedService.getUnifiedFeed();
        final topNews = feed.whereType<NewsItem>().take(2).toList();
        
        if (topNews.isNotEmpty) {
          String reply = 'Here is the latest popular news for you:\n\n';
          for (var i = 0; i < topNews.length; i++) {
            reply += '${i + 1}. 📰 ${topNews[i].title}\n🔗 ${topNews[i].url}\n\n';
          }
          if (!mounted) return;
          setState(() {
            _isTyping = false;
            _messages.add(ChatMessage(text: reply.trim(), isUser: false));
          });
          _scrollToBottom();
          return;
        }
      } catch (_) {
        // If getting news fails, we just fall through to the default analysis block
      }
    }

    try {
      final result = await DirectAnalysisService.analyzeText(text);
      
      // Save it to universal history just like the other analysis tools
      await StorageService.addToHistory(text, result.credibility, resultJson: result.toJson());

      // Construct conversational reply
      final scoreStr = result.credibility.toInt().toString();
      final emoji = result.credibility >= 70 ? '✅' : result.credibility >= 40 ? '⚠️' : '❌';
      final reply = '$emoji I analyzed that claim.\n\n'
          'Credibility Score: $scoreStr/100\n'
          'Verdict: ${result.aiReasoning}';

      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(text: reply, isUser: false, analysisResult: result));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: 'Oops, I hit a snag trying to analyze that: ${e.toString()}',
          isUser: false,
        ));
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF4A342A),
              radius: 16,
              child: const Icon(Icons.smart_toy, color: Color(0xFFD7C9B8), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mira', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.appBarTheme.foregroundColor)),
                Text('Veritas AI', style: TextStyle(fontSize: 11, color: Color(0xFF556B2F), fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator(theme);
                }
                final msg = _messages[index];
                return _buildMessageBubble(msg, theme, isDark);
              },
            ),
          ),
          _buildInputBar(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, ThemeData theme, bool isDark) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: msg.isUser 
              ? const Color(0xFF4A342A) 
              : (isDark ? theme.cardColor : Color(0xFFD7C9B8)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
          border: msg.isUser ? null : Border.all(color: theme.dividerColor),
          boxShadow: [
            if (!msg.isUser) BoxShadow(color: Colors.black.withOpacity(0.02), offset: const Offset(0, 2), blurRadius: 4),
          ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.isUser ? Color(0xFFD7C9B8) : theme.textTheme.bodyLarge?.color,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy, size: 14, color: Color(0xFF4A342A)),
            const SizedBox(width: 8),
            Text('Mira is analyzing...', style: TextStyle(color: Colors.black, fontSize: 13, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2), blurRadius: 4)],
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Message Mira...',
                  hintStyle: TextStyle(color: Colors.black),
                  filled: true,
                  fillColor: isDark ? theme.scaffoldBackgroundColor : Colors.black,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
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
    );
  }
}
