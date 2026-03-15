import os
import re

overlay_path = r"d:\echo guard\echoguard_app\android\app\src\main\kotlin\com\echoguard\echoguard_app\EchoGuardOverlayService.kt"
access_path  = r"d:\echo guard\echoguard_app\android\app\src\main\kotlin\com\echoguard\echoguard_app\EchoGuardAccessibilityService.kt"

# ── 1. Update Overlay ──
with open(overlay_path, "r", encoding="utf-8") as f:
    overlay_content = f.read()

# Replace triggerScan with the robust Selection Mode logic
trigger_regex = re.compile(r"    private fun triggerScan\(\) \{.*?(?=    // ────────────────────────────────────────────\n    // Notification)", re.DOTALL)

selection_code = """    private fun triggerScan() {
        enterSelectionMode()
    }

    private var selectionOverlay: View? = null
    private var confirmView: View? = null

    private fun enterSelectionMode() {
        removeBubble()
        removeResultView()

        val container = object : FrameLayout(this) {
            private val strokePaint = android.graphics.Paint().apply {
                color = Color.parseColor("#4A5D23") // Earthy Olive
                style = android.graphics.Paint.Style.STROKE
                strokeWidth = 10f
            }
            private val bgPaint = android.graphics.Paint().apply {
                color = Color.parseColor("#66000000") // Dim background
            }
            private val clearPaint = android.graphics.Paint().apply {
                xfermode = android.graphics.PorterDuffXfermode(android.graphics.PorterDuff.Mode.CLEAR)
            }

            var startX = 0f
            var startY = 0f
            var currX = 0f
            var currY = 0f
            var isDrawing = false

            override fun onDraw(canvas: android.graphics.Canvas) {
                super.onDraw(canvas)
                canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), bgPaint)
                if (isDrawing) {
                    val rLeft = Math.min(startX, currX)
                    val rTop = Math.min(startY, currY)
                    val rRight = Math.max(startX, currX)
                    val rBottom = Math.max(startY, currY)
                    // Punch a clean hole in the dim background
                    canvas.drawRect(rLeft, rTop, rRight, rBottom, clearPaint)
                    // Draw Stroke
                    canvas.drawRect(rLeft, rTop, rRight, rBottom, strokePaint)
                }
            }

            override fun onTouchEvent(event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        if (confirmView != null) cancelSelection() // user tapped somewhere else while confirm dialog was open
                        startX = event.x
                        startY = event.y
                        currX = event.x
                        currY = event.y
                        isDrawing = true
                        invalidate()
                    }
                    MotionEvent.ACTION_MOVE -> {
                        currX = event.x
                        currY = event.y
                        invalidate()
                    }
                    MotionEvent.ACTION_UP -> {
                        val rLeft = Math.min(startX, currX).toInt()
                        val rTop = Math.min(startY, currY).toInt()
                        val rRight = Math.max(startX, currX).toInt()
                        val rBottom = Math.max(startY, currY).toInt()
                        
                        if (rRight - rLeft > 100 && rBottom - rTop > 100) {
                            showConfirmationDialog(rLeft, rTop, rRight, rBottom)
                        } else {
                            // Canceled by very small tap
                            isDrawing = false
                            invalidate()
                            cancelSelection()
                        }
                    }
                }
                return true
            }
        }
        container.setWillNotDraw(false)
        container.setLayerType(View.LAYER_TYPE_SOFTWARE, null) // Required for CLEAR xfermode

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        selectionOverlay = container
        windowManager?.addView(container, params)
    }

    private fun showConfirmationDialog(left: Int, top: Int, right: Int, bottom: Int) {
        if (confirmView != null) windowManager?.removeViewImmediate(confirmView)

        val container = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor("#4A342A")) // Espresso
            setPadding(24, 24, 24, 24)
            // Round corners
            outlineProvider = object : android.view.ViewOutlineProvider() {
                override fun getOutline(view: View, o: android.graphics.Outline) {
                    o.setRoundRect(0, 0, view.width, view.height, 16f)
                }
            }
            clipToOutline = true
            elevation = 16f
        }

        val btnCancel = android.widget.Button(this).apply {
            text = "✖ Cancel"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { cancelSelection() }
        }
        val btnAnalyze = android.widget.Button(this).apply {
            text = "✔ Analyze"
            setTextColor(Color.parseColor("#4A342A"))
            setBackgroundColor(Color.parseColor("#D7C9B8")) // Khaki
            setOnClickListener {
                confirmSelection(left, top, right - left, bottom - top)
            }
        }
        container.addView(btnCancel)
        container.addView(btnAnalyze)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = Math.max(0, left)
            y = Math.min(resources.displayMetrics.heightPixels - 200, bottom + 20)
        }
        confirmView = container
        windowManager?.addView(container, params)
    }

    private fun cancelSelection() {
        selectionOverlay?.let { windowManager?.removeViewImmediate(it) }
        selectionOverlay = null
        confirmView?.let { windowManager?.removeViewImmediate(it) }
        confirmView = null
        showBubble()
    }

    private fun confirmSelection(left: Int, top: Int, width: Int, height: Int) {
        selectionOverlay?.let { windowManager?.removeViewImmediate(it) }
        selectionOverlay = null
        confirmView?.let { windowManager?.removeViewImmediate(it) }
        confirmView = null

        showBubble()
        (bubbleView as? FrameLayout)?.getChildAt(0)?.setBackgroundColor(Color.parseColor("#F59E0B"))

        val intent = Intent(SCAN_TRIGGER).setPackage(packageName)
        intent.putExtra("cropLeft", left)
        intent.putExtra("cropTop", top)
        intent.putExtra("cropWidth", width)
        intent.putExtra("cropHeight", height)
        sendBroadcast(intent)

        EchoGuardScanBridge.pendingScanTrigger = true
    }
"""

new_overlay_content = trigger_regex.sub(selection_code, overlay_content)
with open(overlay_path, "w", encoding="utf-8") as f:
    f.write(new_overlay_content)



# ── 2. Update Accessibility Service ──
with open(access_path, "r", encoding="utf-8") as f:
    access_content = f.read()

# Update the scanReceiver intent extraction
old_receiver = """    private val scanReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            captureAndAnalyze()
        }
    }"""
new_receiver = """    private val scanReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            val left = intent?.getIntExtra("cropLeft", -1) ?: -1
            val top = intent?.getIntExtra("cropTop", -1) ?: -1
            val width = intent?.getIntExtra("cropWidth", -1) ?: -1
            val height = intent?.getIntExtra("cropHeight", -1) ?: -1
            captureAndAnalyze(left, top, width, height)
        }
    }"""
access_content = access_content.replace(old_receiver, new_receiver)

# Update captureAndAnalyze signature
access_content = access_content.replace("private fun captureAndAnalyze() {", "private fun captureAndAnalyze(cropLeft: Int, cropTop: Int, cropWidth: Int, cropHeight: Int) {")

# Add cropping logic right after softBitmap != null block
old_scale = """                            if (softBitmap == null) {
                                fallbackToTextExtraction()
                                return
                            }

                            // Scale down to keep payload small (~800px wide max)
                            val scaled = scaleBitmap(softBitmap, 800)
                            softBitmap.recycle()"""

new_scale = """                            if (softBitmap == null) {
                                fallbackToTextExtraction()
                                return
                            }

                            // ── Crop ROI if specified ──
                            val finalBitmap = if (cropLeft >= 0 && cropTop >= 0 && cropWidth > 0 && cropHeight > 0) {
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

                            // Scale down to keep payload small (~800px wide max)
                            val scaled = scaleBitmap(finalBitmap, 800)
                            if (scaled !== finalBitmap) finalBitmap.recycle()"""
access_content = access_content.replace(old_scale, new_scale)

with open(access_path, "w", encoding="utf-8") as f:
    f.write(access_content)

print("Patch applied to both Kotlin services successfully.")
