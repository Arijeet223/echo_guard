import 'package:flutter/material.dart';
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
  }

  Future<void> _load() async {
    final items = await StorageService.getHistory();
    setState(() { _all = items; _filtered = items; });
  }

  void _filter(String query) {
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
    if (v == 'Verified') return const Color(0xFF10B981);
    if (v == 'Misleading') return Colors.amber.shade700;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final recent = _filtered.where(_isRecent).toList();
    final older = _filtered.where((i) => !_isRecent(i)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFBF7),
        surfaceTintColor: Colors.transparent,
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: const Color(0xFF1D468B), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.history, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1D468B))),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _showSearch = !_showSearch)),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
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
                  filled: true, fillColor: const Color(0xFFFDFBF7),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E1D8))),
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
      child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey.shade400)),
    );
  }

  Widget _historyCard(HistoryItem item) {
    final color = _verdictColor(item.verdict);
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisScreen(text: item.text)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E1D8)),
          boxShadow: [BoxShadow(color: const Color(0xFF1D468B).withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
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
                        Text(_timeAgo(item), style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
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
                    Text('/100', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                    Text('ECHO SCORE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey.shade400)),
                  ],
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1EEE9)),
            Row(children: [
              Icon(Icons.link, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text('Source: User Input Analyzer', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.history_toggle_off, size: 32, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          const Text('No History Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Analyses you perform will be saved here.', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
