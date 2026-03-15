package com.echoguard.echoguard_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.FrameLayout
import androidx.core.app.NotificationCompat

class EchoGuardOverlayService : Service() {

    companion object {
        const val ACTION_START = "echoguard.START_OVERLAY"
        const val ACTION_STOP  = "echoguard.STOP_OVERLAY"
        const val ACTION_SHOW_RESULT = "echoguard.SHOW_RESULT"
        const val SCAN_TRIGGER = "echoguard.SCAN_TRIGGER"
        const val CHANNEL_ID   = "echoguard_overlay"
        const val NOTIF_ID     = 1001

        // bubble size in dp
        private const val BUBBLE_DP = 64
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: View? = null
    private var resultView: View? = null
    private var loadingOverlay: View? = null
    private lateinit var layoutParams: WindowManager.LayoutParams
    private lateinit var resultLayoutParams: WindowManager.LayoutParams

    // -- drag state --
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var isMoving = false

    private val scanReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            // Relay to MainActivity via static channel
            EchoGuardScanBridge.pendingScanTrigger = true
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification())
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        registerReceiver(scanReceiver, IntentFilter(SCAN_TRIGGER),
            if (Build.VERSION.SDK_INT >= 34) Context.RECEIVER_NOT_EXPORTED else 0)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                removeBubble()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_SHOW_RESULT -> {
                val verdict = intent.getStringExtra("verdict") ?: "Unknown"
                val reason = intent.getStringExtra("reason") ?: ""
                showResultCard(verdict, reason)
            }
            else -> showBubble()
        }
        return START_STICKY
    }

    // ────────────────────────────────────────────
    // Bubble creation
    // ────────────────────────────────────────────
    private fun showBubble() {
        if (bubbleView != null) return   // already showing

        val density = resources.displayMetrics.density
        val sizePx  = (BUBBLE_DP * density).toInt()

        val container = FrameLayout(this)

        // Circular background view — Espresso color
        val bg = View(this)
        bg.setBackgroundColor(Color.parseColor("#4A342A"))
        bg.layoutParams = FrameLayout.LayoutParams(sizePx, sizePx)
        container.addView(bg)

        // "V" icon (Veritas branding, avoids drawable asset dependency)
        val icon = android.widget.TextView(this)
        icon.text = "V"
        icon.textSize = 28f
        icon.setTextColor(Color.parseColor("#D7C9B8"))  // Khaki
        icon.gravity = Gravity.CENTER
        icon.setTypeface(null, android.graphics.Typeface.BOLD)
        icon.layoutParams = FrameLayout.LayoutParams(sizePx, sizePx)
        container.addView(icon)

        // Make the bubble circular via clip-to-outline
        bg.post {
            bg.outlineProvider = object : android.view.ViewOutlineProvider() {
                override fun getOutline(view: View, o: android.graphics.Outline) {
                    o.setOval(0, 0, view.width, view.height)
                }
            }
            bg.clipToOutline = true
        }

        layoutParams = WindowManager.LayoutParams(
            sizePx, sizePx,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 200
        }

        container.setOnTouchListener { _, event ->
            handleTouch(event)
            true
        }

        bubbleView = container
        windowManager?.addView(container, layoutParams)
        EchoGuardScanBridge.overlayRunning = true
    }

    // ────────────────────────────────────────────
    // Loading spinner overlay (shown during analysis)
    // ────────────────────────────────────────────
    private fun showLoadingSpinner() {
        removeLoadingSpinner()
        val density = resources.displayMetrics.density
        val sizePx = (80 * density).toInt()

        val container = FrameLayout(this)
        container.setBackgroundColor(Color.parseColor("#CC4A342A"))
        container.outlineProvider = object : android.view.ViewOutlineProvider() {
            override fun getOutline(view: View, o: android.graphics.Outline) {
                o.setRoundRect(0, 0, view.width, view.height, 16f * density)
            }
        }
        container.clipToOutline = true

        val spinner = android.widget.ProgressBar(this).apply {
            isIndeterminate = true
            layoutParams = FrameLayout.LayoutParams(
                (40 * density).toInt(), (40 * density).toInt(), Gravity.CENTER
            )
            indeterminateTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#D7C9B8"))
        }
        container.addView(spinner)

        val label = android.widget.TextView(this).apply {
            text = "Scanning..."
            textSize = 11f
            setTextColor(Color.parseColor("#D7C9B8"))
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            ).apply { bottomMargin = (6 * density).toInt() }
        }
        container.addView(label)

        val params = WindowManager.LayoutParams(
            sizePx, sizePx,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        loadingOverlay = container
        windowManager?.addView(container, params)
    }

    private fun removeLoadingSpinner() {
        loadingOverlay?.let { windowManager?.removeViewImmediate(it) }
        loadingOverlay = null
    }

    private fun removeBubble() {
        bubbleView?.let {
            windowManager?.removeViewImmediate(it)
            bubbleView = null
        }
        removeResultView()
        EchoGuardScanBridge.overlayRunning = false
    }

    private fun removeResultView() {
        resultView?.let {
            windowManager?.removeViewImmediate(it)
            resultView = null
        }
    }

    // ────────────────────────────────────────────
    // Result Card display
    // ────────────────────────────────────────────
    private fun showResultCard(verdict: String, reason: String) {
        removeResultView() // remove existing if any
        removeLoadingSpinner() // hide the loading spinner
        showBubble() // re-show the idle bubble

        val density = resources.displayMetrics.density
        val container = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#EEFFFFFF")) // slightly transparent white
            setPadding((16*density).toInt(), (16*density).toInt(), (16*density).toInt(), (16*density).toInt())
            
            // outline for rounded corners
            outlineProvider = object : android.view.ViewOutlineProvider() {
                override fun getOutline(view: View, o: android.graphics.Outline) {
                    o.setRoundRect(0, 0, view.width, view.height, 16f * density)
                }
            }
            clipToOutline = true

            // elevate it
            elevation = 8f * density
        }

        // Title / Verdict
        val title = android.widget.TextView(this).apply {
            text = verdict
            textSize = 18f
            setTextColor(if (verdict.contains("True") || verdict.contains("Verified")) Color.parseColor("#0D9488") else Color.parseColor("#DC2626"))
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        container.addView(title)

        // Description / Reason
        val desc = android.widget.TextView(this).apply {
            text = reason
            textSize = 14f
            setTextColor(Color.parseColor("#333333"))
            setPadding(0, (8*density).toInt(), 0, (8*density).toInt())
        }
        container.addView(desc)

        val tapHint = android.widget.TextView(this).apply {
            text = "(Tap anywhere to dismiss)"
            textSize = 12f
            setTextColor(Color.parseColor("#888888"))
        }
        container.addView(tapHint)

        // Tapping dismisses it
        container.setOnClickListener {
            removeResultView()
        }

        resultLayoutParams = WindowManager.LayoutParams(
            (300 * density).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = (200 * density).toInt() // drop it down a bit from the top
        }

        resultView = container
        windowManager?.addView(container, resultLayoutParams)
    }


    // ────────────────────────────────────────────
    // Drag + tap handling
    // ────────────────────────────────────────────
    private fun handleTouch(event: MotionEvent) {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                initialX      = layoutParams.x
                initialY      = layoutParams.y
                initialTouchX = event.rawX
                initialTouchY = event.rawY
                isMoving      = false
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - initialTouchX
                val dy = event.rawY - initialTouchY
                if (Math.abs(dx) > 5 || Math.abs(dy) > 5) isMoving = true
                layoutParams.x = (initialX + dx).toInt()
                layoutParams.y = (initialY + dy).toInt()
                windowManager?.updateViewLayout(bubbleView, layoutParams)
            }
            MotionEvent.ACTION_UP -> {
                if (!isMoving) {
                    // It was a tap — trigger scan
                    triggerScan()
                }
            }
        }
    }

    private fun triggerScan() {
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

        // Show loading spinner while analysis is running
        showLoadingSpinner()

        val intent = Intent(SCAN_TRIGGER).setPackage(packageName)
        intent.putExtra("cropLeft", left)
        intent.putExtra("cropTop", top)
        intent.putExtra("cropWidth", width)
        intent.putExtra("cropHeight", height)
        sendBroadcast(intent)

        EchoGuardScanBridge.pendingScanTrigger = true
    }
    // ────────────────────────────────────────────
    // Notification (required for foreground service)
    // ────────────────────────────────────────────
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "EchoGuard Protection",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "EchoGuard floating scan bubble" }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        val tapIntent = Intent(this, MainActivity::class.java)
        val pi = PendingIntent.getActivity(
            this, 0, tapIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("EchoGuard Protection Active")
            .setContentText("Tap to open EchoGuard")
            .setSmallIcon(android.R.drawable.ic_menu_search)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        removeBubble()
        try { unregisterReceiver(scanReceiver) } catch (_: Exception) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
