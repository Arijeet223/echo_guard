import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/analysis_result.dart';
import '../services/overlay_service.dart';
import '../services/direct_analysis_service.dart';
import '../services/storage_service.dart';
import '../services/language_provider.dart';
import '../services/app_strings.dart';
import 'analysis_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _hasOverlayPermission = false;
  bool _overlayActive = false;
  bool _accessibilityEnabled = false;
  StreamSubscription<String>? _scanSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _checkPermissions();
      _listenForScanResults();
    }
    LanguageProvider.instance.addListener(_onLangChange);
  }

  void _onLangChange() { if (mounted) setState(() {}); }

  Future<void> _checkPermissions() async {
    try {
      final perm = await OverlayService.hasOverlayPermission();
      final active = await OverlayService.isOverlayActive();
      if (mounted) {
        setState(() {
          _hasOverlayPermission = perm;
          _overlayActive = active;
          // Accessibility enabled is a best-effort check; we assume true if
          // the user says they enabled it (no public API to check from Flutter).
          _accessibilityEnabled = false;
        });
      }
    } catch (e) {
      debugPrint('Permission check failed: $e');
    }
  }

  void _listenForScanResults() {
    _scanSub = OverlayService.scanResults.listen((payload) async {
      if (!mounted) return;

      try {
        AnalysisResult result;
        String displayText;

        if (payload.startsWith('__image__:')) {
          // Android 11+ screenshot path
          final base64 = payload.substring('__image__:'.length);
          displayText = '[Screen Screenshot]';
          result = await DirectAnalysisService.analyzeImage(base64);
        } else if (payload.startsWith('__text__:')) {
          // Text extraction fallback (Android 10 and below)
          displayText = payload.substring('__text__:'.length);
          result = await DirectAnalysisService.analyzeText(displayText);
        } else {
          // Legacy format without prefix
          displayText = payload;
          result = await DirectAnalysisService.analyzeText(payload);
        }

        if (!mounted) return;

        // Derive a verdict string from the credibility score
        final verdictText = result.credibility >= 70
            ? '✅ Likely True (${result.credibility.toInt()}%)'
            : result.credibility >= 40
                ? '⚠️ Uncertain (${result.credibility.toInt()}%)'
                : '❌ Likely False (${result.credibility.toInt()}%)';

        // Display results on the native overlay card directly!
        OverlayService.showOverlayResult(
          verdictText,
          result.aiReasoning.isNotEmpty ? result.aiReasoning : 'No details available.',
        );

        // Save to history immediately (can be viewed later inside the app)
        StorageService.addToHistory(displayText, result.credibility, resultJson: result.toJson());
      } catch (e) {
        if (!mounted) return;
        
        // Notify overlay of the error so the bubble stops spinning
        OverlayService.showOverlayResult('Error', e.toString().replaceFirst('Exception: ', ''));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Color(0xFF8B0000),
          ),
        );
      }
    }, onError: (e) => debugPrint('Scan stream error: $e'));
  }

  Future<void> _requestOverlayPermission() async {
    await OverlayService.requestOverlayPermission();
    await Future.delayed(const Duration(seconds: 1));
    await _checkPermissions();
  }

  Future<void> _launchOverlay() async {
    if (!_hasOverlayPermission) {
      await _requestOverlayPermission();
      return;
    }
    try {
      final result = await OverlayService.startOverlay();
      if (mounted) {
        setState(() => _overlayActive = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result == 'permission_required'
                ? '⚠️ Please grant overlay permission, then try again.'
                : '✅ Guardian Bubble launched! Check your screen.'),
            backgroundColor: result == 'permission_required'
                ? Color(0xFFCD853F)
                : const Color(0xFF0D9488),
          ),
        );
        if (result == 'permission_required') {
          await Future.delayed(const Duration(seconds: 2));
          await _checkPermissions();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to launch overlay: $e')),
        );
      }
    }
  }

  Future<void> _stopOverlay() async {
    await OverlayService.stopOverlay();
    if (mounted) setState(() => _overlayActive = false);
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    LanguageProvider.instance.removeListener(_onLangChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (kIsWeb) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(S.get('guardian_overlay'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.appBarTheme.foregroundColor)),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mobile_off, size: 80, color: Colors.black),
                const SizedBox(height: 24),
                Text(S.get('android_exclusive'),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary)),
                const SizedBox(height: 16),
                Text(
                  S.get('android_exclusive_desc'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(S.get('guardian_overlay'),
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.appBarTheme.foregroundColor)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkPermissions,
            tooltip: 'Refresh permissions',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            if (_overlayActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, color: Color(0xFF0D9488)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        S.get('guardian_active'),
                        style: TextStyle(
                            color: const Color(0xFF0D9488),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_moon,
                      size: 40, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.get('system_wide_fc'),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: theme.colorScheme.primary)),
                        const SizedBox(height: 4),
                        Text(
                          S.get('system_wide_desc'),
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodyMedium?.color,
                              height: 1.4),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 32),
            Text(S.get('required_perms'),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            const SizedBox(height: 16),

            _permissionCard(
              context,
              title: S.get('floating_bubble'),
              description: S.get('floating_bubble_desc'),
              icon: Icons.bubble_chart,
              isGranted: _hasOverlayPermission,
              onTap: _requestOverlayPermission,
            ),
            const SizedBox(height: 16),
            _permissionCard(
              context,
              title: S.get('screen_reader'),
              description: S.get('screen_reader_desc'),
              icon: Icons.document_scanner,
              isGranted: _accessibilityEnabled,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(S.get('screen_reader_snack')),
                    duration: Duration(seconds: 4),
                  ),
                );
                setState(() => _accessibilityEnabled = true);
              },
            ),

            const SizedBox(height: 48),

            // Launch / Stop button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _overlayActive ? _stopOverlay : _launchOverlay,
                icon: Icon(
                  _overlayActive ? Icons.stop_circle : Icons.rocket_launch,
                  color: Color(0xFFD7C9B8),
                ),
                label: Text(
                  _overlayActive
                      ? S.get('stop_guardian')
                      : S.get('launch_guardian'),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD7C9B8)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _overlayActive
                      ? Color(0xFF8B0000)
                      : (_hasOverlayPermission
                          ? theme.colorScheme.primary
                          : Colors.black),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Help text
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Color(0xFFCD853F).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFCD853F).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFFCD853F), size: 18),
                      const SizedBox(width: 8),
                      Text(S.get('how_to_access'),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFCD853F))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    S.get('access_steps'),
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFCD853F),
                        height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionCard(BuildContext context,
      {required String title,
      required String description,
      required IconData icon,
      required bool isGranted,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isGranted
                  ? Color(0xFF556B2F).withOpacity(0.5)
                  : theme.dividerColor,
              width: isGranted ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGranted
                    ? Color(0xFF556B2F).withOpacity(0.1)
                    : theme.scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color:
                      isGranted ? Color(0xFF556B2F) : Colors.black),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isGranted ? Icons.check_circle : Icons.chevron_right,
              color: isGranted ? Color(0xFF556B2F) : Colors.black,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
