import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

/// ──────────────────────────────────────────────────────────────
///  OVERLAY ENTRY POINT — Runs in an ISOLATED Flutter engine
///  DO NOT import flutter_accessibility_service here.
///  DO NOT use anything that requires the main app's bindings.
/// ──────────────────────────────────────────────────────────────
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ShazamBubble(),
    ),
  );
}

class ShazamBubble extends StatefulWidget {
  const ShazamBubble({super.key});

  @override
  State<ShazamBubble> createState() => _ShazamBubbleState();
}

class _ShazamBubbleState extends State<ShazamBubble>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _analyzing = false;
  bool _hasResult = false;

  double _score = 0;
  String _verdict = '';
  Color _verdictColor = Color(0xFF556B2F);
  String _reasoning = '';
  List<String> _sources = [];

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Simple pulse animation for the idle bubble — Shazam style
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ──── TAP: Expand to show Analyse button ────
  void _onBubbleTap() {
    if (_analyzing) return;
    setState(() => _expanded = true);
    FlutterOverlayWindow.resizeOverlay(260, 160, false);
  }

  // ──── CLOSE: Collapse back to bubble ────
  void _collapse() {
    setState(() {
      _expanded = false;
      _hasResult = false;
      _analyzing = false;
    });
    FlutterOverlayWindow.resizeOverlay(120, 120, false);
  }

  // ──── ANALYSE: Send screen text to backend ────
  Future<void> _analyse() async {
    setState(() {
      _analyzing = true;
      _expanded = false;
    });
    // Resize to show the loading spinner
    FlutterOverlayWindow.resizeOverlay(120, 120, false);

    try {
      // We send a generic request — the backend uses the Mercury 2 AI
      // The overlay cannot read screen text directly (that requires the main app).
      // So we'll send a signal to analyze whatever is on screen.
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': 'Analyze the content currently displayed on screen'}),
      ).timeout(const Duration(seconds: 35));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final score = (data['credibility'] as num).toDouble();
        setState(() {
          _analyzing = false;
          _hasResult = true;
          _score = score;
          _verdict = score >= 70
              ? 'Likely True'
              : (score >= 40 ? 'Uncertain' : 'Likely False');
          _verdictColor = score >= 70
              ? Color(0xFF556B2F)
              : (score >= 40 ? Color(0xFFCD853F) : Color(0xFF8B0000));
          _reasoning =
              data['ai_reasoning']?.toString() ?? 'No details available.';
          _sources = List<String>.from(data['balanced_views'] ?? []);
        });
        // Resize to show result panel
        FlutterOverlayWindow.resizeOverlay(
          WindowSize.matchParent, 380, false);
      } else {
        throw Exception('Server ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _analyzing = false;
        _hasResult = true;
        _score = 0;
        _verdict = 'Error';
        _verdictColor = Color(0xFF8B0000);
        _reasoning = 'Could not reach Veritas server.\n$e';
        _sources = [];
      });
      FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, 380, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ───── RESULT PANEL ─────
    if (_hasResult) {
      return Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFD7C9B8),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 3),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(Icons.shield, color: _verdictColor, size: 26),
                      const SizedBox(width: 8),
                      Text(_verdict,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _verdictColor)),
                    ]),
                    GestureDetector(
                      onTap: _collapse,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 18, color: Colors.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Echo Score: ${_score.toStringAsFixed(0)}/100',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54)),
                const Divider(height: 16),
                Text(_reasoning,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87, height: 1.4),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis),
                if (_sources.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Sources:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                  const SizedBox(height: 4),
                  ..._sources.take(2).map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(children: [
                          Icon(Icons.check_circle,
                              size: 12, color: _verdictColor),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(s,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                        ]),
                      )),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // ───── EXPANDED: Analyse button card ─────
    if (_expanded) {
      return Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFFD7C9B8),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF4A342A).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo.png', width: 20, height: 20),
                    const SizedBox(width: 6),
                    const Text('Veritas',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A342A))),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _collapse,
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _analyse,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A342A), Color(0xFFB2967D)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.saved_search,
                            color: Color(0xFFD7C9B8), size: 18),
                        SizedBox(width: 4),
                        Text('Analyse',
                            style: TextStyle(
                                color: Color(0xFFD7C9B8),
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ───── IDLE: Shazam-style floating circle ─────
    return Material(
      color: Colors.transparent,
      child: Center(
        child: GestureDetector(
          onTap: _onBubbleTap,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.08);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A342A), Color(0xFFB2967D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A342A).withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                    border: Border.all(color: Color(0xFFD7C9B8), width: 3),
                  ),
                  child: _analyzing
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                              color: Color(0xFF4A342A), strokeWidth: 3),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/logo.png', width: 28, height: 28),
                            SizedBox(height: 2),
                            Text('SCAN',
                                style: TextStyle(
                                    color: Color(0xFF4A342A),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
