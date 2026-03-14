package com.echoguard.echoguard_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val OVERLAY_CHANNEL  = "echoguard/overlay"
    private val SCAN_RESULT_CHANNEL = "echoguard/scan_results"

    private var scanEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── MethodChannel: Flutter → Native commands ──────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startOverlay" -> {
                        if (!Settings.canDrawOverlays(this)) {
                            // Ask for permission first
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success("permission_required")
                        } else {
                            startOverlayService()
                            result.success("started")
                        }
                    }
                    "stopOverlay" -> {
                        stopOverlayService()
                        result.success("stopped")
                    }
                    "isOverlayActive" -> {
                        result.success(EchoGuardScanBridge.overlayRunning)
                    }
                    "hasOverlayPermission" -> {
                        result.success(Settings.canDrawOverlays(this))
                    }
                    "requestOverlayPermission" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── EventChannel: Native → Flutter scan results ────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCAN_RESULT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    scanEventSink = events
                    // Wire the bridge callback
                    EchoGuardScanBridge.onScanResult = { text ->
                        runOnUiThread { events?.success(text) }
                    }
                }
                override fun onCancel(arguments: Any?) {
                    scanEventSink = null
                    EchoGuardScanBridge.onScanResult = null
                }
            })
    }

    private fun startOverlayService() {
        val intent = Intent(this, EchoGuardOverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopOverlayService() {
        val intent = Intent(this, EchoGuardOverlayService::class.java).apply {
            action = EchoGuardOverlayService.ACTION_STOP
        }
        startService(intent)
    }
}
