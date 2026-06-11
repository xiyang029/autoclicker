package com.example.autoclicker

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.roundToInt
import kotlin.random.Random

class FloatingOverlayService : Service() {
    companion object {
        private const val CONTROL_X_KEY = "controlX"
        private const val CONTROL_Y_KEY = "controlY"
        private const val TARGET_X_KEY = "targetX"
        private const val TARGET_Y_KEY = "targetY"
        private const val CLICKS_PER_SECOND_KEY = "clicksPerSecond"
        private const val JITTER_RADIUS_KEY = "jitterRadius"
        private const val TARGET_SIZE_KEY = "targetSize"
        private const val CONFIGURATION_LIST_KEY = "configurationList"
        const val ACTION_SAVE_CONFIGURATION = "com.example.autoclicker.SAVE_CONFIGURATION"
        const val ACTION_CONFIGURATION_LIST_CHANGED =
            "com.example.autoclicker.CONFIGURATION_LIST_CHANGED"
        const val PREFERENCES_NAME = "floating_overlay"
        const val DEFAULT_CLICKS_PER_SECOND = 8.0
        const val DEFAULT_JITTER_RADIUS = 6.0
        const val DEFAULT_TARGET_SIZE = 32.0
        const val DEFAULT_TARGET_X = 180
        const val DEFAULT_TARGET_Y = 300
    }

    private lateinit var windowManager: WindowManager
    private val clickHandler = Handler(Looper.getMainLooper())
    private var controlView: View? = null
    private var targetView: View? = null
    private var controlParams: WindowManager.LayoutParams? = null
    private var targetParams: WindowManager.LayoutParams? = null
    private var clickRunnable: Runnable? = null
    private var running = false
    private var clicksPerSecond = DEFAULT_CLICKS_PER_SECOND
    private var jitterRadius = DEFAULT_JITTER_RADIUS
    private var targetSize = DEFAULT_TARGET_SIZE
    private var targetX = DEFAULT_TARGET_X
    private var targetY = DEFAULT_TARGET_Y
    private var targetOnly = false

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val preferences = preferences()
        clicksPerSecond = intent?.getDoubleExtra(
            "clicksPerSecond",
            preferences.getFloat(CLICKS_PER_SECOND_KEY, DEFAULT_CLICKS_PER_SECOND.toFloat())
                .toDouble()
        ) ?: preferences.getFloat(CLICKS_PER_SECOND_KEY, DEFAULT_CLICKS_PER_SECOND.toFloat())
            .toDouble()
        jitterRadius = intent?.getDoubleExtra(
            "jitterRadius",
            preferences.getFloat(JITTER_RADIUS_KEY, DEFAULT_JITTER_RADIUS.toFloat()).toDouble()
        ) ?: preferences.getFloat(JITTER_RADIUS_KEY, DEFAULT_JITTER_RADIUS.toFloat()).toDouble()
        targetSize = intent?.getDoubleExtra(
            "targetSize",
            preferences.getFloat(TARGET_SIZE_KEY, DEFAULT_TARGET_SIZE.toFloat()).toDouble()
        ) ?: preferences.getFloat(TARGET_SIZE_KEY, DEFAULT_TARGET_SIZE.toFloat()).toDouble()
        targetX = intent?.getDoubleExtra(
            "targetX",
            preferences.getInt(TARGET_X_KEY, DEFAULT_TARGET_X).toDouble()
        )?.roundToInt() ?: preferences.getInt(TARGET_X_KEY, DEFAULT_TARGET_X)
        targetY = intent?.getDoubleExtra(
            "targetY",
            preferences.getInt(TARGET_Y_KEY, DEFAULT_TARGET_Y).toDouble()
        )?.roundToInt() ?: preferences.getInt(TARGET_Y_KEY, DEFAULT_TARGET_Y)
        targetOnly = intent?.getBooleanExtra("targetOnly", false) ?: false

        if (intent?.action == ACTION_SAVE_CONFIGURATION) {
            if (targetView != null) {
                updateTargetSize()
                updateTargetPosition()
                restartClickLoopIfRunning()
            }
            saveConfiguration()
            return START_STICKY
        }

        if (targetView == null) {
            showOverlay()
        } else {
            updateTargetSize()
            updateTargetPosition()
            updateControlVisibility()
            restartClickLoopIfRunning()
        }

        return START_STICKY
    }

    override fun onDestroy() {
        stopClickLoop()
        removeOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun showOverlay() {
        val preferences = preferences()

        targetParams = WindowManager.LayoutParams(
            targetSize.roundToInt(),
            targetSize.roundToInt(),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            baseWindowFlags(),
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = targetX
            y = targetY
        }
        targetView = TargetReticleView(this).also { view ->
            attachDragHandler(view, view, targetParams!!)
            windowManager.addView(view, targetParams)
        }

        if (targetOnly) return

        controlParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            baseWindowFlags(),
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = preferences.getInt(CONTROL_X_KEY, dp(8))
            y = preferences.getInt(CONTROL_Y_KEY, dp(120))
        }
        controlView = createControlView().also { view ->
            windowManager.addView(view, controlParams)
        }
    }

    private fun createControlView(): View {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(8), dp(8), dp(8))
            background = OverlayPanelDrawable()
        }
        attachDragHandler(container, container, controlParams!!)

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        val startButton = overlayIconButton(
            R.drawable.ic_overlay_play,
            "开始"
        )
        startButton.setOnClickListener {
            if (running) {
                stopClickLoop()
                startButton.alpha = 1f
                startButton.contentDescription = "开始"
            } else if (startClickLoop()) {
                startButton.alpha = 0.62f
                startButton.contentDescription = "停止"
            } else {
                startButton.alpha = 0.42f
            }
        }

        val saveButton = overlayIconButton(
            R.drawable.ic_overlay_save,
            "保存"
        )
        saveButton.setOnClickListener {
            savePositions()
            addConfiguration()
            Toast.makeText(this, "已保存为新配置", Toast.LENGTH_SHORT).show()
        }

        val closeButton = overlayIconButton(
            R.drawable.ic_overlay_close,
            "关闭",
            destructive = true
        )
        closeButton.setOnClickListener {
            stopSelf()
        }

        actions.addView(startButton)
        actions.addView(saveButton)
        actions.addView(closeButton)
        container.addView(actions)

        return container
    }

    private fun updateControlVisibility() {
        if (targetOnly) {
            removeControlView()
            return
        }

        if (controlView != null) return

        val preferences = preferences()
        controlParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            baseWindowFlags(),
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = preferences.getInt(CONTROL_X_KEY, dp(8))
            y = preferences.getInt(CONTROL_Y_KEY, dp(120))
        }
        controlView = createControlView().also { view ->
            windowManager.addView(view, controlParams)
        }
    }

    private fun overlayIconButton(
        iconResource: Int,
        label: String,
        destructive: Boolean = false
    ): ImageButton {
        val size = dp(36)
        return ImageButton(this).apply {
            contentDescription = label
            minimumWidth = size
            minimumHeight = size
            setImageResource(iconResource)
            setColorFilter(if (destructive) Color.rgb(251, 114, 153) else Color.WHITE)
            setPadding(dp(8), dp(8), dp(8), dp(8))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(8).toFloat()
                setColor(
                    if (destructive) {
                        Color.WHITE
                    } else {
                        Color.argb(46, 255, 255, 255)
                    }
                )
            }
            scaleType = ImageView.ScaleType.CENTER
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                bottomMargin = dp(8)
            }
            setOnTouchListener { view, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        view.isPressed = true
                        true
                    }

                    MotionEvent.ACTION_UP -> {
                        view.isPressed = false
                        view.performClick()
                        true
                    }

                    MotionEvent.ACTION_CANCEL -> {
                        view.isPressed = false
                        true
                    }

                    else -> false
                }
            }
        }
    }

    private fun attachDragHandler(
        dragHandle: View,
        windowView: View,
        params: WindowManager.LayoutParams
    ) {
        dragHandle.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }

                    MotionEvent.ACTION_MOVE -> {
                        params.x = initialX + (event.rawX - initialTouchX).roundToInt()
                        params.y = initialY + (event.rawY - initialTouchY).roundToInt()
                        windowManager.updateViewLayout(windowView, params)
                        if (windowView == targetView) {
                            targetX = params.x
                            targetY = params.y
                            saveTargetPosition()
                        }
                        return true
                    }
                }
                return false
            }
        })
    }

    private fun startClickLoop(): Boolean {
        val target = targetParams ?: return false
        val targetWindow = targetView ?: return false
        val centerX = target.x + targetWindow.width / 2f
        val centerY = target.y + targetWindow.height / 2f

        setTargetTouchable(false)
        if (!AutoClickAccessibilityService.performTap(centerX, centerY)) {
            setTargetTouchable(true)
            return false
        }

        running = true
        val intervalMs = (1000.0 / clicksPerSecond.coerceIn(1.0, 20.0))
            .roundToInt()
            .coerceAtLeast(50)

        clickRunnable = object : Runnable {
            override fun run() {
                val currentTarget = targetParams
                val currentTargetView = targetView
                if (!running || currentTarget == null || currentTargetView == null) {
                    return
                }

                val jitter = jitterRadius.coerceAtLeast(0.0)
                val x = currentTarget.x + currentTargetView.width / 2f +
                    Random.nextDouble(-jitter, jitter).toFloat()
                val y = currentTarget.y + currentTargetView.height / 2f +
                    Random.nextDouble(-jitter, jitter).toFloat()
                AutoClickAccessibilityService.performTap(x, y)
                clickHandler.postDelayed(this, intervalMs.toLong())
            }
        }
        clickHandler.postDelayed(clickRunnable!!, intervalMs.toLong())

        return true
    }

    private fun stopClickLoop() {
        running = false
        clickRunnable?.let {
            clickHandler.removeCallbacks(it)
        }
        clickRunnable = null
        setTargetTouchable(true)
    }

    private fun restartClickLoopIfRunning() {
        if (!running) return

        stopClickLoop()
        startClickLoop()
    }

    private fun updateTargetSize() {
        val target = targetParams ?: return
        val targetWindow = targetView ?: return
        val size = targetSize.roundToInt()
        target.width = size
        target.height = size
        windowManager.updateViewLayout(targetWindow, target)
    }

    private fun updateTargetPosition() {
        val target = targetParams ?: return
        val targetWindow = targetView ?: return
        target.x = targetX
        target.y = targetY
        windowManager.updateViewLayout(targetWindow, target)
    }

    private fun setTargetTouchable(touchable: Boolean) {
        val target = targetParams ?: return
        val targetWindow = targetView ?: return
        target.flags = if (touchable) {
            baseWindowFlags()
        } else {
            baseWindowFlags() or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        windowManager.updateViewLayout(targetWindow, target)
    }

    private fun baseWindowFlags(): Int {
        return WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
    }

    private fun savePositions() {
        val control = controlParams ?: return
        val target = targetParams ?: return

        preferences()
            .edit()
            .putInt(CONTROL_X_KEY, control.x)
            .putInt(CONTROL_Y_KEY, control.y)
            .putInt(TARGET_X_KEY, target.x)
            .putInt(TARGET_Y_KEY, target.y)
            .putFloat(CLICKS_PER_SECOND_KEY, clicksPerSecond.toFloat())
            .putFloat(JITTER_RADIUS_KEY, jitterRadius.toFloat())
            .putFloat(TARGET_SIZE_KEY, targetSize.toFloat())
            .apply()
    }

    private fun saveTargetPosition() {
        val target = targetParams ?: return

        preferences()
            .edit()
            .putInt(TARGET_X_KEY, target.x)
            .putInt(TARGET_Y_KEY, target.y)
            .apply()
    }

    private fun addConfiguration() {
        val preferences = preferences()
        val saved = preferences.getString(CONFIGURATION_LIST_KEY, null)
        val configurations = if (saved.isNullOrBlank()) JSONArray() else JSONArray(saved)
        val nextIndex = configurations.length() + 1

        configurations.put(
            JSONObject().apply {
                put("id", System.nanoTime().toString())
                put("name", "配置 $nextIndex")
                put("clicksPerSecond", clicksPerSecond)
                put("jitterRadius", jitterRadius)
                put("targetSize", targetSize)
                put("targetX", targetParams?.x ?: targetX)
                put("targetY", targetParams?.y ?: targetY)
            }
        )

        preferences
            .edit()
            .putString(CONFIGURATION_LIST_KEY, configurations.toString())
            .apply()
        sendBroadcast(Intent(ACTION_CONFIGURATION_LIST_CHANGED).setPackage(packageName))
    }

    private fun saveConfiguration() {
        val editor = preferences()
            .edit()
            .putFloat(CLICKS_PER_SECOND_KEY, clicksPerSecond.toFloat())
            .putFloat(JITTER_RADIUS_KEY, jitterRadius.toFloat())
            .putFloat(TARGET_SIZE_KEY, targetSize.toFloat())

        controlParams?.let { control ->
            editor.putInt(CONTROL_X_KEY, control.x)
            editor.putInt(CONTROL_Y_KEY, control.y)
        }
        targetParams?.let { target ->
            editor.putInt(TARGET_X_KEY, target.x)
            editor.putInt(TARGET_Y_KEY, target.y)
        }

        editor
            .apply()
        Toast.makeText(this, "已保存当前参数", Toast.LENGTH_SHORT).show()
    }

    private fun removeOverlay() {
        removeControlView()
        targetView?.let {
            windowManager.removeView(it)
        }
        targetView = null
        targetParams = null
    }

    private fun removeControlView() {
        controlView?.let {
            windowManager.removeView(it)
        }
        controlView = null
        controlParams = null
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).roundToInt()
    }

    private fun preferences() = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
}

private class TargetReticleView(context: Context) : View(context) {
    private val crossPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(251, 114, 153)
        strokeCap = Paint.Cap.ROUND
        strokeWidth = 8f
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val centerX = width / 2f
        val centerY = height / 2f
        val padding = width.coerceAtMost(height) * 0.2f

        canvas.drawLine(centerX, padding, centerX, height - padding, crossPaint)
        canvas.drawLine(padding, centerY, width - padding, centerY, crossPaint)
    }
}

private class OverlayPanelDrawable : GradientDrawable() {
    init {
        setColor(Color.rgb(251, 114, 153))
        cornerRadius = 24f
    }
}
