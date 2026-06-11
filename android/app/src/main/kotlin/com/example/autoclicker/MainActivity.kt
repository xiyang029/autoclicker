package com.example.autoclicker

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private companion object {
        const val CONFIGURATION_LIST_KEY = "configurationList"
    }

    private val channelName = "autoclicker/android"
    private val preferencesName = FloatingOverlayService.PREFERENCES_NAME
    private var channel: MethodChannel? = null
    private var configurationListReceiverRegistered = false
    private val configurationListChangedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            channel?.invokeMethod("configurationListChanged", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isOverlayPermissionGranted" -> {
                        result.success(canDrawOverlays())
                    }

                    "isAccessibilityPermissionGranted" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }

                    "openOverlaySettings" -> {
                        openOverlaySettings()
                        result.success(null)
                    }

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }

                    "startOverlayService" -> {
                        if (!canDrawOverlays()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        startService(
                            overlayServiceIntent(
                                clicksPerSecond = call.argument<Double>("clicksPerSecond")
                                    ?: FloatingOverlayService.DEFAULT_CLICKS_PER_SECOND,
                                jitterRadius = call.argument<Double>("jitterRadius")
                                    ?: FloatingOverlayService.DEFAULT_JITTER_RADIUS,
                                targetSize = call.argument<Double>("targetSize")
                                    ?: FloatingOverlayService.DEFAULT_TARGET_SIZE,
                                targetX = call.argument<Double>("targetX")
                                    ?: FloatingOverlayService.DEFAULT_TARGET_X.toDouble(),
                                targetY = call.argument<Double>("targetY")
                                    ?: FloatingOverlayService.DEFAULT_TARGET_Y.toDouble(),
                                targetOnly = call.argument<Boolean>("targetOnly") ?: false
                            )
                        )
                        result.success(true)
                    }

                    "loadOverlayConfiguration" -> {
                        result.success(loadOverlayConfiguration())
                    }

                    "saveOverlayConfiguration" -> {
                        val clicksPerSecond = call.argument<Double>("clicksPerSecond") ?: FloatingOverlayService.DEFAULT_CLICKS_PER_SECOND
                        val jitterRadius = call.argument<Double>("jitterRadius") ?: FloatingOverlayService.DEFAULT_JITTER_RADIUS
                        val targetSize = call.argument<Double>("targetSize") ?: FloatingOverlayService.DEFAULT_TARGET_SIZE
                        val targetX = call.argument<Double>("targetX") ?: FloatingOverlayService.DEFAULT_TARGET_X.toDouble()
                        val targetY = call.argument<Double>("targetY") ?: FloatingOverlayService.DEFAULT_TARGET_Y.toDouble()

                        saveOverlayConfiguration(
                            clicksPerSecond = clicksPerSecond,
                            jitterRadius = jitterRadius,
                            targetSize = targetSize,
                            targetX = targetX,
                            targetY = targetY
                        )

                        if (canDrawOverlays()) {
                            startService(
                                overlayServiceIntent(
                                    action = FloatingOverlayService.ACTION_SAVE_CONFIGURATION,
                                    clicksPerSecond = clicksPerSecond,
                                    jitterRadius = jitterRadius,
                                    targetSize = targetSize,
                                    targetX = targetX,
                                    targetY = targetY
                                )
                            )
                        }
                        result.success(null)
                    }

                    "loadConfigurationList" -> {
                        result.success(loadConfigurationList())
                    }

                    "saveConfigurationList" -> {
                        val configurations =
                            call.argument<List<Map<String, Any?>>>("configurations") ?: emptyList()
                        saveConfigurationList(configurations)
                        result.success(null)
                    }

                    "stopOverlayService" -> {
                        stopService(Intent(this, FloatingOverlayService::class.java))
                        result.success(null)
                    }

                    "getAppVersionName" -> {
                        result.success(packageManager.getPackageInfo(packageName, 0).versionName)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        if (configurationListReceiverRegistered) return

        val filter = IntentFilter(FloatingOverlayService.ACTION_CONFIGURATION_LIST_CHANGED)
        ContextCompat.registerReceiver(
            this,
            configurationListChangedReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        configurationListReceiverRegistered = true
    }

    override fun onStop() {
        if (configurationListReceiverRegistered) {
            unregisterReceiver(configurationListChangedReceiver)
            configurationListReceiverRegistered = false
        }
        super.onStop()
    }

    private fun loadConfigurationList(): List<Map<String, Any>> {
        val saved = preferences()
            .getString(CONFIGURATION_LIST_KEY, null)
            ?: return emptyList()
        val array = JSONArray(saved)
        return List(array.length()) { index ->
            val item = array.getJSONObject(index)
            mapOf(
                "id" to item.optString("id"),
                "name" to item.optString("name"),
                "clicksPerSecond" to item.optDouble("clicksPerSecond", FloatingOverlayService.DEFAULT_CLICKS_PER_SECOND),
                "jitterRadius" to item.optDouble("jitterRadius", FloatingOverlayService.DEFAULT_JITTER_RADIUS),
                "targetSize" to item.optDouble("targetSize", FloatingOverlayService.DEFAULT_TARGET_SIZE),
                "targetX" to item.optDouble("targetX", FloatingOverlayService.DEFAULT_TARGET_X.toDouble()),
                "targetY" to item.optDouble("targetY", FloatingOverlayService.DEFAULT_TARGET_Y.toDouble())
            )
        }
    }

    private fun saveConfigurationList(configurations: List<Map<String, Any?>>) {
        val array = JSONArray()
        configurations.forEach { item ->
            array.put(
                JSONObject().apply {
                    put("id", item["id"] as? String ?: "")
                    put("name", item["name"] as? String ?: "")
                    put("clicksPerSecond", (item["clicksPerSecond"] as? Number)?.toDouble() ?: FloatingOverlayService.DEFAULT_CLICKS_PER_SECOND)
                    put("jitterRadius", (item["jitterRadius"] as? Number)?.toDouble() ?: FloatingOverlayService.DEFAULT_JITTER_RADIUS)
                    put("targetSize", (item["targetSize"] as? Number)?.toDouble() ?: FloatingOverlayService.DEFAULT_TARGET_SIZE)
                    put("targetX", (item["targetX"] as? Number)?.toDouble() ?: FloatingOverlayService.DEFAULT_TARGET_X.toDouble())
                    put("targetY", (item["targetY"] as? Number)?.toDouble() ?: FloatingOverlayService.DEFAULT_TARGET_Y.toDouble())
                }
            )
        }
        preferences()
            .edit()
            .putString(CONFIGURATION_LIST_KEY, array.toString())
            .apply()
    }

    private fun preferences() = getSharedPreferences(preferencesName, Context.MODE_PRIVATE)

    private fun loadOverlayConfiguration(): Map<String, Double> {
        val preferences = preferences()
        return mapOf(
            "clicksPerSecond" to preferences.getFloat(
                "clicksPerSecond",
                FloatingOverlayService.DEFAULT_CLICKS_PER_SECOND.toFloat()
            ).toDouble(),
            "jitterRadius" to preferences.getFloat(
                "jitterRadius",
                FloatingOverlayService.DEFAULT_JITTER_RADIUS.toFloat()
            ).toDouble(),
            "targetSize" to preferences.getFloat(
                "targetSize",
                FloatingOverlayService.DEFAULT_TARGET_SIZE.toFloat()
            ).toDouble(),
            "targetX" to preferences.getInt(
                "targetX",
                FloatingOverlayService.DEFAULT_TARGET_X
            ).toDouble(),
            "targetY" to preferences.getInt(
                "targetY",
                FloatingOverlayService.DEFAULT_TARGET_Y
            ).toDouble()
        )
    }

    private fun saveOverlayConfiguration(
        clicksPerSecond: Double,
        jitterRadius: Double,
        targetSize: Double,
        targetX: Double,
        targetY: Double
    ) {
        preferences()
            .edit()
            .putFloat("clicksPerSecond", clicksPerSecond.toFloat())
            .putFloat("jitterRadius", jitterRadius.toFloat())
            .putFloat("targetSize", targetSize.toFloat())
            .putInt("targetX", targetX.toInt())
            .putInt("targetY", targetY.toInt())
            .apply()
    }

    private fun overlayServiceIntent(
        action: String? = null,
        clicksPerSecond: Double,
        jitterRadius: Double,
        targetSize: Double,
        targetX: Double,
        targetY: Double,
        targetOnly: Boolean = false
    ) = Intent(this, FloatingOverlayService::class.java).apply {
        this.action = action
        putExtra("clicksPerSecond", clicksPerSecond)
        putExtra("jitterRadius", jitterRadius)
        putExtra("targetSize", targetSize)
        putExtra("targetX", targetX)
        putExtra("targetY", targetY)
        putExtra("targetOnly", targetOnly)
    }

    private fun canDrawOverlays(): Boolean {
        return Settings.canDrawOverlays(this)
    }

    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        )
        startActivity(intent)
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedServiceName = ComponentName(
            this,
            AutoClickAccessibilityService::class.java
        ).flattenToString()
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        return enabledServices.split(':').any {
            it.equals(expectedServiceName, ignoreCase = true)
        }
    }
}
