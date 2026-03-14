import 'package:flutter/services.dart';

/// Flutter wrapper around the native [echoguard/overlay] MethodChannel
/// and the [echoguard/scan_results] EventChannel.
///
/// Usage:
///   await OverlayService.startOverlay();
///   OverlayService.scanResults.listen((text) { ... });
class OverlayService {
  OverlayService._();

  static const _method = MethodChannel('echoguard/overlay');
  static const _events = EventChannel('echoguard/scan_results');

  // ── Commands ───────────────────────────────────────────────────────────
  static Future<String> startOverlay() async {
    final result = await _method.invokeMethod<String>('startOverlay');
    return result ?? 'unknown';
  }

  static Future<void> stopOverlay() =>
      _method.invokeMethod('stopOverlay');

  static Future<bool> hasOverlayPermission() async {
    final result = await _method.invokeMethod<bool>('hasOverlayPermission');
    return result ?? false;
  }

  static Future<void> requestOverlayPermission() =>
      _method.invokeMethod('requestOverlayPermission');

  static Future<bool> isOverlayActive() async {
    final result = await _method.invokeMethod<bool>('isOverlayActive');
    return result ?? false;
  }

  // ── Scan results stream (text extracted from screen) ──────────────────
  /// Emits a [String] each time the floating bubble is tapped and the
  /// accessibility service extracts screen text.
  static Stream<String> get scanResults =>
      _events.receiveBroadcastStream().map((e) => e.toString());
}
