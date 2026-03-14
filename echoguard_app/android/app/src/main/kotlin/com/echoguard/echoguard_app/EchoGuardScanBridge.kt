package com.echoguard.echoguard_app

/**
 * Lightweight in-process bridge between:
 *   EchoGuardOverlayService  ← produces scan triggers
 *   EchoGuardAccessibilityService ← produces extracted text
 *   MainActivity ← consumes both and forwards to Flutter
 *
 * Using a simple singleton avoids the complexity of a bound service
 * while keeping everything in the same process.
 */
object EchoGuardScanBridge {
    /** Set to true when the overlay bubble is tapped. */
    @Volatile var pendingScanTrigger: Boolean = false

    /** Most recent text extracted by the accessibility service. */
    @Volatile var lastExtractedText: String = ""

    /** Whether the overlay bubble is currently visible. */
    @Volatile var overlayRunning: Boolean = false

    /** Callback invoked on the main thread when scan results arrive. */
    var onScanResult: ((String) -> Unit)? = null
}
