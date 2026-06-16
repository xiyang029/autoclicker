package com.example.autoclicker

import android.Manifest
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val INSTALLER_CHANNEL_NAME = "autoclicker/installer"
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 7201
    }

    private val channelName = "autoclicker/android"
    private val preferencesName = OVERLAY_PREFERENCES_NAME
    private var channel: MethodChannel? = null
    private var notificationPermissionResult: MethodChannel.Result? = null
    private var configurationListReceiverRegistered = false
    private var overlayServiceStoppedReceiverRegistered = false
    private val configurationListChangedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            channel?.invokeMethod("configurationListChanged", null)
        }
    }
    private val overlayServiceStoppedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            channel?.invokeMethod("overlayServiceStopped", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasNotificationPermission" -> {
                        result.success(hasNotificationPermission())
                    }

                    "isOverlayPermissionGranted" -> {
                        result.success(canDrawOverlays())
                    }

                    "isAccessibilityPermissionGranted" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }

                    "isOverlayServiceRunning" -> {
                        result.success(preferences().readOverlayServiceRunning())
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
                                overlayConfig = call.readOverlayConfig(),
                                targetOnly = call.isTargetOnly(),
                            )
                        )
                        result.success(true)
                    }

                    "loadOverlayConfiguration" -> {
                        result.success(loadOverlayConfiguration())
                    }

                    "saveOverlayConfiguration" -> {
                        val overlayConfig = call.readOverlayConfig()
                        saveOverlayConfiguration(overlayConfig)

                        if (canDrawOverlays()) {
                            startService(
                                overlayServiceIntent(
                                    action = FloatingOverlayService.ACTION_SAVE_CONFIGURATION,
                                    overlayConfig = overlayConfig,
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    result.success(canRequestPackageInstalls())
                }

                "openInstallPermissionSettings" -> {
                    openInstallPermissionSettings()
                    result.success(null)
                }

                "showToast" -> {
                    showToast(call.argument<String>("message") ?: "")
                    result.success(null)
                }

                "ensureNotificationPermission" -> {
                    ensureNotificationPermission(result)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) return

        val allowed = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        notificationPermissionResult?.success(allowed)
        notificationPermissionResult = null
    }

    override fun onStart() {
        super.onStart()
        if (!configurationListReceiverRegistered) {
            val filter = IntentFilter(FloatingOverlayService.ACTION_CONFIGURATION_LIST_CHANGED)
            ContextCompat.registerReceiver(
                this,
                configurationListChangedReceiver,
                filter,
                ContextCompat.RECEIVER_NOT_EXPORTED
            )
            configurationListReceiverRegistered = true
        }

        if (!overlayServiceStoppedReceiverRegistered) {
            val overlayStoppedFilter =
                IntentFilter(FloatingOverlayService.ACTION_OVERLAY_SERVICE_STOPPED)
            ContextCompat.registerReceiver(
                this,
                overlayServiceStoppedReceiver,
                overlayStoppedFilter,
                ContextCompat.RECEIVER_NOT_EXPORTED
            )
            overlayServiceStoppedReceiverRegistered = true
        }
    }

    override fun onStop() {
        if (configurationListReceiverRegistered) {
            unregisterReceiver(configurationListChangedReceiver)
            configurationListReceiverRegistered = false
        }
        if (overlayServiceStoppedReceiverRegistered) {
            unregisterReceiver(overlayServiceStoppedReceiver)
            overlayServiceStoppedReceiverRegistered = false
        }
        super.onStop()
    }

    private fun loadConfigurationList(): List<Map<String, Any>> {
        return OverlayConfig.listFromPreferences(preferences(), CONFIGURATION_LIST_KEY).map { item ->
            val overlayConfig = OverlayConfig.fromJson(item)
            mapOf(
                "id" to item.optString("id"),
                "name" to item.optString("name"),
                "clicksPerSecond" to overlayConfig.clicksPerSecond,
                "jitterRadius" to overlayConfig.jitterRadius,
                "targetSize" to overlayConfig.targetSize,
                "targetX" to overlayConfig.targetX.toDouble(),
                "targetY" to overlayConfig.targetY.toDouble(),
            )
        }
    }

    private fun saveConfigurationList(configurations: List<Map<String, Any?>>) {
        OverlayConfig.saveListToPreferences(
            preferences(),
            CONFIGURATION_LIST_KEY,
            configurations.map { item ->
                item.toOverlayConfig().toJson(
                    id = item["id"] as? String ?: "",
                    name = item["name"] as? String ?: "",
                )
            },
        )
    }

    private fun preferences() = getSharedPreferences(preferencesName, Context.MODE_PRIVATE)

    private fun loadOverlayConfiguration(): Map<String, Double> {
        return OverlayConfig.fromPreferences(preferences()).toPreferenceMap()
    }

    private fun saveOverlayConfiguration(overlayConfig: OverlayConfig) {
        overlayConfig.saveToPreferences(preferences())
    }

    private fun overlayServiceIntent(
        action: String? = null,
        overlayConfig: OverlayConfig,
        targetOnly: Boolean = false
    ) = Intent(this, FloatingOverlayService::class.java).apply {
        this.action = action
        putExtra("clicksPerSecond", overlayConfig.clicksPerSecond)
        putExtra("jitterRadius", overlayConfig.jitterRadius)
        putExtra("targetSize", overlayConfig.targetSize)
        putExtra("targetX", overlayConfig.targetX.toDouble())
        putExtra("targetY", overlayConfig.targetY.toDouble())
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

    private fun canRequestPackageInstalls(): Boolean {
        return packageManager.canRequestPackageInstalls()
    }

    private fun hasNotificationPermission(): Boolean {
        val permissionGranted =
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        return permissionGranted && NotificationManagerCompat.from(this).areNotificationsEnabled()
    }

    private fun openInstallPermissionSettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName"),
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun ensureNotificationPermission(result: MethodChannel.Result) {
        val permissionGranted =
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        val notificationsEnabled = NotificationManagerCompat.from(this).areNotificationsEnabled()

        if (permissionGranted && notificationsEnabled) {
            result.success(true)
            return
        }

        if (permissionGranted && !notificationsEnabled) {
            openNotificationSettings()
            result.success(false)
            return
        }

        if (notificationPermissionResult != null) {
            result.success(false)
            return
        }

        notificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE
        )
    }

    private fun showToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
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

    private fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun MethodCall.readOverlayConfig(): OverlayConfig {
        return OverlayConfig.fromMethodCall(this)
    }

    private fun MethodCall.isTargetOnly(): Boolean {
        return argument<Boolean>("targetOnly") ?: false
    }

    private fun Map<String, Any?>.toOverlayConfig(): OverlayConfig {
        return OverlayConfig(
            clicksPerSecond =
                (this["clicksPerSecond"] as? Number)?.toDouble()
                    ?: OverlayConfig.DEFAULT_CLICKS_PER_SECOND,
            jitterRadius =
                (this["jitterRadius"] as? Number)?.toDouble()
                    ?: OverlayConfig.DEFAULT_JITTER_RADIUS,
            targetSize =
                (this["targetSize"] as? Number)?.toDouble()
                    ?: OverlayConfig.DEFAULT_TARGET_SIZE,
            targetX =
                (this["targetX"] as? Number)?.toDouble()?.toInt() ?: OverlayConfig.DEFAULT_TARGET_X,
            targetY =
                (this["targetY"] as? Number)?.toDouble()?.toInt() ?: OverlayConfig.DEFAULT_TARGET_Y,
        )
    }
}
