package com.echoguard.echoguard_app

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class EchoGuardAccessibilityService : AccessibilityService() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private val scanReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            captureAndAnalyze()
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        registerReceiver(
            scanReceiver,
            IntentFilter(EchoGuardOverlayService.SCAN_TRIGGER),
            if (Build.VERSION.SDK_INT >= 34) Context.RECEIVER_NOT_EXPORTED else 0
        )
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(scanReceiver) } catch (_: Exception) {}
        executor.shutdown()
    }

    // ────────────────────────────────────────────
    // Main entry: screenshot on Android 11+, text fallback otherwise
    // ────────────────────────────────────────────
    private fun captureAndAnalyze() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ — capture screenshot via AccessibilityService API
            takeScreenshot(
                Display.DEFAULT_DISPLAY,
                executor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(screenshot: ScreenshotResult) {
                        try {
                            // Convert HardwareBitmap → software bitmap → JPEG base64
                            val hwBitmap = Bitmap.wrapHardwareBuffer(
                                screenshot.hardwareBuffer, screenshot.colorSpace
                            )
                            screenshot.hardwareBuffer.close()

                            val softBitmap = hwBitmap?.copy(Bitmap.Config.ARGB_8888, false)
                            hwBitmap?.recycle()

                            if (softBitmap == null) {
                                fallbackToTextExtraction()
                                return
                            }

                            // Scale down to keep payload small (~800px wide max)
                            val scaled = scaleBitmap(softBitmap, 800)
                            softBitmap.recycle()

                            val stream = ByteArrayOutputStream()
                            scaled.compress(Bitmap.CompressFormat.JPEG, 70, stream)
                            scaled.recycle()

                            val base64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                            deliverImage(base64)
                        } catch (e: Exception) {
                            fallbackToTextExtraction()
                        }
                    }

                    override fun onFailure(errorCode: Int) {
                        // takeScreenshot failed (e.g., protected window) → fall back
                        fallbackToTextExtraction()
                    }
                }
            )
        } else {
            // Android 10 and below — extract text from accessibility tree
            fallbackToTextExtraction()
        }
    }

    // ────────────────────────────────────────────
    // Fallback: text extraction via accessibility tree
    // ────────────────────────────────────────────
    private fun fallbackToTextExtraction() {
        val root = rootInActiveWindow
        if (root == null) {
            mainHandler.post {
                EchoGuardScanBridge.onScanResult?.invoke(
                    "__text__:(Could not access screen — ensure Accessibility is enabled)"
                )
            }
            return
        }
        val texts = mutableListOf<String>()
        collectTexts(root, texts)
        root.recycle()

        val combined = texts
            .filter { it.isNotBlank() && it.length > 3 }
            .distinct()
            .joinToString(" ")
            .trim()

        val result = if (combined.isBlank())
            "__text__:(No readable text found on this screen)"
        else
            "__text__:$combined"

        mainHandler.post {
            EchoGuardScanBridge.onScanResult?.invoke(result)
        }
    }

    private fun deliverImage(base64: String) {
        mainHandler.post {
            EchoGuardScanBridge.onScanResult?.invoke("__image__:$base64")
        }
    }

    private fun collectTexts(node: AccessibilityNodeInfo?, out: MutableList<String>) {
        if (node == null) return
        val text = node.text?.toString()
        val desc = node.contentDescription?.toString()
        if (!text.isNullOrBlank()) out.add(text)
        else if (!desc.isNullOrBlank()) out.add(desc)
        for (i in 0 until node.childCount) collectTexts(node.getChild(i), out)
    }

    private fun scaleBitmap(src: Bitmap, maxWidth: Int): Bitmap {
        if (src.width <= maxWidth) return src
        val ratio = maxWidth.toFloat() / src.width
        val h = (src.height * ratio).toInt()
        return Bitmap.createScaledBitmap(src, maxWidth, h, true)
    }
}
