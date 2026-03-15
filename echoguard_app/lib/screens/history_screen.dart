import 'package:flutter/material.dart';
import '../models/analysis_result.dart';
import '../services/storage_service.dart';
import 'analysis_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> _all = [];
  List<HistoryItem> _filtered = [];
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    StorageService.historyNotifier.addListener(_load);
  }

  @override
  void dispose() {
    StorageService.historyNotifier.removeListener(_load);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await StorageService.getHistory();
    if (!mounted) return;
    setState(() { 
      _all = items; 
      _filtered = items.where((i) => i.text.toLowerCase().contains(_searchCtrl.text.toLowerCase()) || i.verdict.toLowerCase().contains(_searchCtrl.text.toLowerCase())).toList();
    });
  }

  void _filter(String query) {
    if (!mounted) return;
    setState(() {
      _filtered = _all.where((i) => i.text.toLowerCase().contains(query.toLowerCase()) || i.verdict.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  bool _isRecent(HistoryItem item) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(item.id));
    return diff.inHours < 24;
  }

  String _timeAgo(HistoryItem item) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(item.id));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateTime.fromMillisecondsSinceEpoch(item.id).toString().substring(0, 10);
  }

  Color _verdictColor(String v) {
    if (v == 'Verified') return const Color(0xFF4A5D23); // Earthy Olive
    if (v == 'Misleading') return const Color(0xFFC19A6B); // Earthy Mustard
    return const Color(0xFF8B3A3A); // Earthy Rust
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = _filtered.where(_isRecent).toList();
    final older = _filtered.where((i) => !_isRecent(i)).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Row(children: [
          const Icon(Icons.access_time, size: 28),
          const SizedBox(width: 10),
          Text('History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.appBarTheme.foregroundColor)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _showSearch = !_showSearch)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Color(0xFF4A342A)),
            onSelected: (cat) {
              setState(() {
                if (cat == 'All') {
                  _searchCtrl.clear();
                  _filtered = _all;
                } else {
                  _searchCtrl.text = cat;
                  _filter(cat);
                  _showSearch = true;
                }
              });
            },
            itemBuilder: (context) => [
              'All', 'Political', 'Geopolitical', 'Sports', 'Tech', 'Health', 'Finance', 'Crypto'
            ].map((c) => PopupMenuItem(value: c, child: Text(c))).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'Search past analyses...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true, fillColor: theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          Expanded(
            child: _filtered.isEmpty
                ? _emptyState()
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (recent.isNotEmpty) ...[
                        _sectionTitle('PAST 24 HOURS'),
                        ...recent.map(_historyCard),
                        const SizedBox(height: 24),
                      ],
                      if (older.isNotEmpty) ...[
                        _sectionTitle('OLDER'),
                        ...older.map(_historyCard),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.black)),
    );
  }

  Widget _historyCard(HistoryItem item) {
    final color = _verdictColor(item.verdict);
    return Builder(builder: (context) {
      final theme = Theme.of(context);
      return GestureDetector(
      onTap: () {
          AnalysisResult? preloaded;
          if (item.resultJson != null) {
            try {
              preloaded = AnalysisResult.fromJson(item.resultJson!);
            } catch (_) {}
          }
          final textToAnalyze = item.fullText.isNotEmpty ? item.fullText : item.text;
          Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisScreen(text: textToAnalyze, preloadedResult: preloaded)));
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text(item.verdict, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                        ),
                        const SizedBox(width: 8),
                        Text(_timeAgo(item), style: TextStyle(fontSize: 12, color: Colors.black)),
                      ]),
                      const SizedBox(height: 8),
                      Text(item.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${item.score.toStringAsFixed(0)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                    Text('/100', style: TextStyle(fontSize: 10, color: Colors.black)),
                    Text('ECHO SCORE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.black)),
                  ],
                ),
              ],
            ),
            Divider(height: 20, color: theme.dividerColor),
            Row(children: [
              Icon(Icons.link, size: 14, color: Colors.black),
              const SizedBox(width: 6),
              Text('Source: User Input Analyzer', style: TextStyle(fontSize: 11, color: Colors.black)),
            ]),
          ],
        ),
      ),
    );
    });
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            child: Icon(Icons.history_toggle_off, size: 32, color: Colors.black),
          ),
          const SizedBox(height: 16),
          const Text('No History Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Analyses you perform will be saved here.', style: TextStyle(fontSize: 14, color: Colors.black)),
        ],
      ),
    );
  }
}
