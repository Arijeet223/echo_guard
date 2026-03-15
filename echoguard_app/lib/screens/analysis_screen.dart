import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/analysis_result.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AnalysisScreen extends StatefulWidget {
  final String text;
  final AnalysisResult? preloadedResult;
  const AnalysisScreen({super.key, required this.text, this.preloadedResult});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  AnalysisResult? _result;
  bool _loading = true;
  String? _error;
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  bool _feedbackSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedResult != null) {
      // Image/overlay analysis already done — skip the API call
      _result = widget.preloadedResult;
      _loading = false;
      // Save to history (same as text analysis path)
      StorageService.addToHistory(widget.text, widget.preloadedResult!.credibility, resultJson: widget.preloadedResult!.toJson());
    } else {
      _fetchAnalysis();
    }
  }

  Future<void> _fetchAnalysis() async {
    try {
      AnalysisResult result;
      // Detect URL vs plain text
      final t = widget.text.trim();
      if (t.startsWith('http://') || t.startsWith('https://')) {
        result = await ApiService.analyzeUrl(t);
      } else {
        result = await ApiService.analyzeText(t);
      }
      await StorageService.addToHistory(widget.text, result.credibility, resultJson: result.toJson());
      setState(() { _result = result; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 70) return const Color(0xFF556B2F);
    if (score >= 40) return Color(0xFFCD853F);
    return Color(0xFF8B0000);
  }

  String _getScoreLabel(double score) {
    if (score >= 70) return 'Verified';
    if (score >= 40) return 'Misleading';
    return 'High Risk';
  }

  Future<void> _speak() async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }
    final d = _result!;
    final text = 'Veritas Analysis Complete. Credibility score is ${d.credibility.toStringAsFixed(0)} percent. '
        'Manipulation alert is ${d.manipulation.level}. Dominant emotion is ${d.manipulation.emotion}. '
        'Bias meter reads ${d.bias.leaning} leaning. '
        'Clickbait is ${d.clickbait.isClickbait ? "detected" : "not detected"}. '
        '${d.aiReasoning}';
    setState(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => setState(() => _isSpeaking = false));
    await _tts.speak(text);
  }

  Future<void> _sendFeedback(String type) async {
    setState(() => _feedbackSent = true);
    try { await ApiService.sendFeedback(type); } catch (_) {}
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text('Veritas Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.appBarTheme.foregroundColor)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              if (_result != null) {
                final d = _result!;
                final scoreEmoji = d.credibility >= 70 ? '✅' : d.credibility >= 40 ? '⚠️' : '❌';
                final shareText = '🔍 Veritas Analysis:\n\n'
                    '"${widget.text}"\n\n'
                    '$scoreEmoji Credibility Score: ${d.credibility.toInt()}/100\n'
                    '🧠 AI Verdict: ${d.aiReasoning}\n\n'
                    '— Verified by Veritas';
                Share.share(shareText);
              }
            },
          )
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildResults(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 64, height: 64, child: CircularProgressIndicator(strokeWidth: 4, color: Color(0xFF4A342A))),
          const SizedBox(height: 24),
          const Text('Analyzing Content...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Cross-referencing trusted sources\nand detecting manipulation patterns.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFF8B0000)),
          const SizedBox(height: 16),
          const Text('Analysis Failed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Could not connect to the backend.\nMake sure FastAPI is running.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () { setState(() { _loading = true; _error = null; }); _fetchAnalysis(); }, child: const Text('Try Again')),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final d = _result!;
    final color = _getScoreColor(d.credibility);
    final label = _getScoreLabel(d.credibility);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Speak Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _speak,
              icon: Icon(_isSpeaking ? Icons.stop_circle : Icons.volume_up, size: 16),
              label: Text(_isSpeaking ? 'Stop Reading' : 'Speak Analysis', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A342A),
                foregroundColor: Color(0xFFD7C9B8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Credibility Score Card
          _card(
            child: Column(
              children: [
                Align(alignment: Alignment.centerLeft, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                )),
                const SizedBox(height: 16),
                Text('CREDIBILITY SCORE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.black)),
                const SizedBox(height: 16),
                _buildGauge(d.credibility, color),
                const SizedBox(height: 12),
                Text('Fake Probability: ${d.fakeProbability.toStringAsFixed(1)}%', style: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _expandableReasoning(d.aiReasoning),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Metrics Grid
          Row(
            children: [
              Expanded(child: _manipulationCard(d)),
              const SizedBox(width: 12),
              Expanded(child: _biasCard(d)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _sourceCard(d)),
              const SizedBox(width: 12),
              Expanded(child: _clickbaitCard(d)),
            ],
          ),

          const SizedBox(height: 12),

          // Balanced Perspectives
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.diversity_3, color: Color(0xFF4A342A), size: 20),
                    const SizedBox(width: 8),
                    const Text('Balanced Perspectives', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 24),
                ...d.balancedViews.map((v) {
                  final parts = v.split(' - ');
                  final title = parts.isNotEmpty ? parts[0] : v;
                  final source = parts.length > 1 ? parts[1] : 'Web Source';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(source, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(title, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Feedback
          _card(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                Text('RATE THIS ANALYSIS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.black)),
                const SizedBox(height: 12),
                if (_feedbackSent)
                  const Text('Thank you for your feedback!', style: TextStyle(color: Color(0xFF4A342A), fontWeight: FontWeight.w600, fontSize: 13))
                else
                  Row(
                    children: [
                      _feedbackBtn('Accurate', Color(0xFF556B2F)),
                      const SizedBox(width: 8),
                      _feedbackBtn('Misleading', Color(0xFF8B0000)),
                      const SizedBox(width: 8),
                      _feedbackBtn('Unclear', Colors.black),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGauge(double score, Color color) {
    return Builder(builder: (context) {
      final theme = Theme.of(context);
      return SizedBox(
        width: 160, height: 160,
        child: CustomPaint(
          painter: _GaugePainter(score, color, theme.dividerColor),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${score.toStringAsFixed(0)}', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: color)),
                Text('%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _expandableReasoning(String reasoning) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: const Text('Why did we give this score?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      children: [Text(reasoning, style: TextStyle(fontSize: 13, color: Colors.black, height: 1.5))],
    );
  }

  Widget _manipulationCard(AnalysisResult d) {
    final isHigh = d.manipulation.level == 'HIGH';
    final isMed = d.manipulation.level == 'MEDIUM';
    final badgeColor = isHigh ? Color(0xFF8B0000) : isMed ? Color(0xFFCD853F) : Colors.black;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.campaign, color: Color(0xFF8B0000), size: 18),
            const SizedBox(width: 6),
            const Expanded(child: Text('Manipulation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(d.manipulation.level, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor)),
            ),
          ]),
          const SizedBox(height: 12),
          Text('${d.manipulation.emotion} (${d.manipulation.intensity.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: d.manipulation.intensity / 100, backgroundColor: const Color(0xFFF5F0E6), color: badgeColor, minHeight: 4),
          if (d.manipulation.keywords.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 4, runSpacing: 4, children: d.manipulation.keywords.map((w) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFD7C9B8), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.black)),
              child: Text('"$w"', style: TextStyle(fontSize: 10, color: Colors.black)),
            )).toList()),
          ],
        ],
      ),
    );
  }

  Widget _biasCard(AnalysisResult d) {
    final isNeutral = d.bias.leaning == 'NEUTRAL';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.balance, color: Color(0xFFCD853F), size: 18),
            const SizedBox(width: 6),
            const Expanded(child: Text('Bias Meter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: (isNeutral ? Color(0xFF556B2F) : Color(0xFFCD853F)).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(d.bias.leaning, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isNeutral ? Color(0xFF556B2F) : Color(0xFFCD853F))),
            ),
          ]),
          const SizedBox(height: 12),
          Center(child: Text('${d.bias.leaning} LEANING', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          const SizedBox(height: 4),
          Center(child: Text('Confidence: ${d.bias.confidence.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: Colors.black))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(flex: 1, child: Container(height: 6, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(width: 2),
            Expanded(flex: 1, child: Container(height: 6, color: Colors.black)),
            const SizedBox(width: 2),
            Expanded(flex: 1, child: Container(height: 6, decoration: BoxDecoration(color: Color(0xFF8B0000), borderRadius: BorderRadius.circular(3)))),
          ]),
          if (d.bias.propagandaFlag) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Color(0xFF8B0000).withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Color(0xFF8B0000).withOpacity(0.2))),
              child: Row(children: [
                Icon(Icons.flag, size: 12, color: Color(0xFF8B0000)),
                const SizedBox(width: 4),
                Text('Propaganda pattern likely', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8B0000))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sourceCard(AnalysisResult d) {
    final isHigh = d.sourceReliability.level == 'HIGH';
    final isMed = d.sourceReliability.level == 'MEDIUM';
    final badgeColor = isHigh ? Color(0xFF556B2F) : isMed ? Color(0xFFCD853F) : Color(0xFF8B0000);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.verified, color: Color(0xFF059669), size: 18),
            const SizedBox(width: 6),
            const Expanded(child: Text('Source', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(d.sourceReliability.level, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor)),
            ),
          ]),
          const SizedBox(height: 12),
          _metricRow('Domain', d.sourceReliability.domain),
          const SizedBox(height: 8),
          _metricRow('Trust Score', '${d.sourceReliability.score}/100', valueColor: badgeColor),
        ],
      ),
    );
  }

  Widget _clickbaitCard(AnalysisResult d) {
    final isClickbait = d.clickbait.isClickbait;
    final color = isClickbait ? Color(0xFF8B0000) : const Color(0xFF556B2F);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.ads_click, color: Colors.pink, size: 18),
            const SizedBox(width: 6),
            const Expanded(child: Text('Clickbait', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              child: Text(isClickbait ? 'DETECTED' : 'NONE', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFD7C9B8))),
            ),
          ]),
          const SizedBox(height: 12),
          Text(isClickbait ? 'YES' : 'NO', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, letterSpacing: 1)),
          Text('Probability: ${d.clickbait.probability.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: Colors.black)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: d.clickbait.probability / 100,
            backgroundColor: const Color(0xFFF5F0E6),
            color: color,
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, {Color? valueColor}) {
    return Builder(builder: (context) {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.black)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? Theme.of(context).textTheme.bodyLarge?.color)),
      ]);
    });
  }

  Widget _feedbackBtn(String label, Color color) {
    return Builder(builder: (context) {
      return Expanded(
        child: OutlinedButton(
          onPressed: () => _sendFeedback(label),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Theme.of(context).dividerColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black)),
        ),
      );
    });
  }

  Widget _card({required Widget child, Color? color}) {
    return Builder(builder: (context) {
      final theme = Theme.of(context);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );
    });
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;
  final Color bgColor;
  _GaugePainter(this.score, this.color, this.bgColor);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background arc
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, 2 * pi, false, bgPaint);

    // Score arc
    final scorePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, 2 * pi * (score / 100), false, scorePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
