package com.example.autoclicker

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.view.accessibility.AccessibilityEvent

class AutoClickAccessibilityService : AccessibilityService() {
    companion object {
        private var currentService: AutoClickAccessibilityService? = null

        fun performTap(x: Float, y: Float): Boolean {
            return currentService?.dispatchTap(x, y) ?: false
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        currentService = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        if (currentService == this) {
            currentService = null
        }
        super.onDestroy()
    }

    private fun dispatchTap(x: Float, y: Float): Boolean {
        val path = Path().apply {
            moveTo(x, y)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 24))
            .build()

        return dispatchGesture(gesture, null, null)
    }
}
