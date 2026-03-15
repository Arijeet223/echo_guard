package com.echoguard.echoguard_app

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class EchoGuardAccessibilityService : AccessibilityService() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private val scanReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            val left = intent?.getIntExtra("cropLeft", -1) ?: -1
            val top = intent?.getIntExtra("cropTop", -1) ?: -1
            val width = intent?.getIntExtra("cropWidth", -1) ?: -1
            val height = intent?.getIntExtra("cropHeight", -1) ?: -1
            captureAndAnalyze(left, top, width, height)
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
    private fun captureAndAnalyze(cropLeft: Int, cropTop: Int, cropWidth: Int, cropHeight: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            takeScreenshot(
                Display.DEFAULT_DISPLAY,
                executor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(screenshot: ScreenshotResult) {
                        try {
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

                            // ── Crop ROI if specified ──
                            val croppedBitmap = if (cropLeft >= 0 && cropTop >= 0 && cropWidth > 0 && cropHeight > 0) {
                                val rLeft = Math.max(0, cropLeft)
                                val rTop = Math.max(0, cropTop)
                                val rWidth = Math.min(softBitmap.width - rLeft, cropWidth)
                                val rHeight = Math.min(softBitmap.height - rTop, cropHeight)
                                val cropped = Bitmap.createBitmap(softBitmap, rLeft, rTop, rWidth, rHeight)
                                softBitmap.recycle()
                                cropped
                            } else {
                                softBitmap
                            }

                            // ── Face detection + blur ──
                            detectAndBlurFaces(croppedBitmap) { blurredBitmap ->
                                val scaled = scaleBitmap(blurredBitmap, 800)
                                if (scaled !== blurredBitmap) blurredBitmap.recycle()

                                val stream = ByteArrayOutputStream()
                                scaled.compress(Bitmap.CompressFormat.JPEG, 70, stream)
                                scaled.recycle()

                                val base64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                                deliverImage(base64)
                            }
                        } catch (e: Exception) {
                            fallbackToTextExtraction()
                        }
                    }

                    override fun onFailure(errorCode: Int) {
                        fallbackToTextExtraction()
                    }
                }
            )
        } else {
            fallbackToTextExtraction()
        }
    }

    // ────────────────────────────────────────────
    // Face Detection + Pixelation Blur (ML Kit)
    // ────────────────────────────────────────────
    private fun detectAndBlurFaces(bitmap: Bitmap, onComplete: (Bitmap) -> Unit) {
        val options = FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
            .build()
        val detector = FaceDetection.getClient(options)
        val inputImage = InputImage.fromBitmap(bitmap, 0)

        detector.process(inputImage)
            .addOnSuccessListener { faces ->
                if (faces.isEmpty()) {
                    onComplete(bitmap)
                    return@addOnSuccessListener
                }
                // Create a mutable copy to draw blurs on
                val mutableBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, true)
                bitmap.recycle()

                val canvas = Canvas(mutableBitmap)
                val paint = Paint()

                for (face in faces) {
                    val bounds = face.boundingBox
                    // Pixelate approach: scale down the face region then scale back up
                    val faceW = Math.max(1, bounds.width())
                    val faceH = Math.max(1, bounds.height())
                    val safeLeft = Math.max(0, bounds.left)
                    val safeTop = Math.max(0, bounds.top)
                    val safeRight = Math.min(mutableBitmap.width, bounds.right)
                    val safeBottom = Math.min(mutableBitmap.height, bounds.bottom)
                    val safeFaceW = safeRight - safeLeft
                    val safeFaceH = safeBottom - safeTop

                    if (safeFaceW > 0 && safeFaceH > 0) {
                        val faceRegion = Bitmap.createBitmap(mutableBitmap, safeLeft, safeTop, safeFaceW, safeFaceH)
                        // Scale down to 8px wide (heavy pixelation)
                        val pixelated = Bitmap.createScaledBitmap(faceRegion, 8, 8, false)
                        faceRegion.recycle()
                        // Scale back up to original face size
                        val blurred = Bitmap.createScaledBitmap(pixelated, safeFaceW, safeFaceH, false)
                        pixelated.recycle()
                        // Draw over the original face region
                        canvas.drawBitmap(blurred, safeLeft.toFloat(), safeTop.toFloat(), paint)
                        blurred.recycle()
                    }
                }
                detector.close()
                onComplete(mutableBitmap)
            }
            .addOnFailureListener {
                // Face detection failed — continue without blur
                detector.close()
                onComplete(bitmap)
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
