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
        const val SCAN_TRIGGER = "echoguard.SCAN_TRIGGER"
        const val CHANNEL_ID   = "echoguard_overlay"
        const val NOTIF_ID     = 1001

        // bubble size in dp
        private const val BUBBLE_DP = 64
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: View? = null
    private lateinit var layoutParams: WindowManager.LayoutParams

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

        // Outer container so the touch target is generous
        val container = FrameLayout(this)

        // Circular background view
        val bg = View(this)
        bg.setBackgroundColor(Color.parseColor("#1D468B"))  // EchoGuard blue
        bg.layoutParams = FrameLayout.LayoutParams(sizePx, sizePx)
        container.addView(bg)

        // Shield icon label (unicode shield — avoids drawable asset dependency)
        val icon = android.widget.TextView(this)
        icon.text = "🛡"
        icon.textSize = 26f
        icon.gravity = Gravity.CENTER
        icon.layoutParams = FrameLayout.LayoutParams(sizePx, sizePx)
        container.addView(icon)

        // Make the bubble circular via clip-to-outline
        bg.post {
            bg.pivotX = sizePx / 2f
            bg.pivotY = sizePx / 2f
            val outline = android.graphics.Outline()
            outline.setOval(0, 0, sizePx, sizePx)
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

    private fun removeBubble() {
        bubbleView?.let {
            windowManager?.removeViewImmediate(it)
            bubbleView = null
        }
        EchoGuardScanBridge.overlayRunning = false
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
        // Tell the accessibility service to collect screen text
        val intent = Intent(SCAN_TRIGGER).setPackage(packageName)
        sendBroadcast(intent)
        // Also set the bridge flag so MainActivity can pick it up
        EchoGuardScanBridge.pendingScanTrigger = true
        // Temporarily pulse the bubble yellow
        (bubbleView as? FrameLayout)?.getChildAt(0)?.setBackgroundColor(Color.parseColor("#F59E0B"))
        bubbleView?.postDelayed({
            (bubbleView as? FrameLayout)?.getChildAt(0)?.setBackgroundColor(Color.parseColor("#1D468B"))
        }, 600)
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
