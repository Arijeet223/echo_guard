import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'analysis_screen.dart';
import 'dart:async';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _hasOverlayPermission = false;
  bool _hasAccessibilityPermission = false;
  SendPort? homePort;
  String? portName = "EchoGuardOverlayPort";
  StreamSubscription? _overlaySubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _setupOverlayListener();
  }

  void _setupOverlayListener() {
    if (kIsWeb) return;
    
    IsolateNameServer.removePortNameMapping(portName!);
    final res = IsolateNameServer.registerPortWithName(
      ReceivePort().sendPort,
      portName!,
    );
    
    // Listen for data coming from the overlay bubble
    _overlaySubscription = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event != null && event is Map) {
        if (event['intent'] == 'scan_complete' && event['text'] != null) {
          // Open the Analysis screen with extracted text
          Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisScreen(text: event['text'])));
        }
      }
    });
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      _overlaySubscription?.cancel();
      IsolateNameServer.removePortNameMapping(portName!);
    }
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (kIsWeb) return;
    try {
      final overlay = await FlutterOverlayWindow.isPermissionGranted();
      final accessibility = await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
      setState(() {
        _hasOverlayPermission = overlay;
        _hasAccessibilityPermission = accessibility;
      });
    } catch (e) {
      debugPrint("Permission check failed: $e");
    }
  }

  Future<void> _requestOverlay() async {
    if (!_hasOverlayPermission) {
      final granted = await FlutterOverlayWindow.requestPermission() ?? false;
      setState(() => _hasOverlayPermission = granted);
    }
  }

  Future<void> _requestAccessibility() async {
    if (!_hasAccessibilityPermission) {
      // Show an instructional dialog first because Android Accessibility settings are deeply buried
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Action Required'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('To read screen text, EchoGuard needs Accessibility access. Android will now open your Settings.'),
              SizedBox(height: 16),
              Text('Please follow these exact steps:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('1. Scroll down and tap "Installed apps" or "Downloaded apps"'),
              SizedBox(height: 4),
              Text('2. Find and tap "EchoGuard"'),
              SizedBox(height: 4),
              Text('3. Toggle the switch to "On" and tap "Allow"'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await FlutterAccessibilityService.requestAccessibilityPermission();
                _checkPermissions();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _launchOverlay() async {
    if (_hasOverlayPermission && _hasAccessibilityPermission) {
      // Always close any stale/invisible overlay first, then relaunch fresh
      try {
        if (await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
          // Small delay to let the system clean up
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (_) {}
      
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "EchoGuard Scanner",
        overlayContent: "Tap to scan for misinformation",
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.centerLeft,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: 120,
        width: 120,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Guardian Bubble launched! Check your screen.'),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please grant all permissions first.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Guardian Overlay is an Android-exclusive feature. Display fallback on Web/Chrome.
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text('Guardian Overlay', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.appBarTheme.foregroundColor)),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mobile_off, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 24),
                Text(
                  'Android Exclusive Feature',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  'The System-Wide Guardian Bubble requires native Android App permissions (Draw Over Other Apps & Accessibility) to extract text from your screen. Please install the APK on an Android device to use this feature.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.android, color: Colors.white),
                  label: const Text('Download APK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
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
        title: Text('Guardian Overlay', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.appBarTheme.foregroundColor)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_moon, size: 40, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('System-Wide Fact Checking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary)),
                        const SizedBox(height: 4),
                        Text('EchoGuard can float over other apps like Twitter or WhatsApp to instantly scan and verify claims on your screen.', 
                             style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color, height: 1.4)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Text('Required Permissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            
            _permissionCard(
              context,
              title: 'Floating Bubble',
              description: 'Allows EchoGuard to draw a hovering button over other apps.',
              icon: Icons.bubble_chart,
              isGranted: _hasOverlayPermission,
              onTap: _requestOverlay,
            ),
            const SizedBox(height: 16),
            _permissionCard(
              context,
              title: 'Screen Reader',
              description: 'Allows EchoGuard to extract text from the screen when you tap the bubble.',
              icon: Icons.document_scanner,
              isGranted: _hasAccessibilityPermission,
              onTap: _requestAccessibility,
            ),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _launchOverlay,
                icon: const Icon(Icons.rocket_launch, color: Colors.white),
                label: const Text('Launch Guardian Overlay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_hasOverlayPermission && _hasAccessibilityPermission) ? theme.colorScheme.primary : Colors.grey.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: (_hasOverlayPermission && _hasAccessibilityPermission) ? 4 : 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionCard(BuildContext context, {required String title, required String description, required IconData icon, required bool isGranted, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isGranted ? Colors.green.withOpacity(0.5) : theme.dividerColor, width: isGranted ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGranted ? Colors.green.withOpacity(0.1) : theme.scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isGranted ? Colors.green : Colors.grey.shade500),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isGranted ? Icons.check_circle : Icons.chevron_right,
              color: isGranted ? Colors.green : Colors.grey.shade400,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
