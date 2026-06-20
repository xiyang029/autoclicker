package com.example.autoclicker

import android.content.Intent
import android.content.SharedPreferences
import io.flutter.plugin.common.MethodCall
import org.json.JSONObject
import kotlin.math.roundToInt

private const val CLICKS_PER_SECOND_KEY = "clicksPerSecond"
private const val JITTER_RADIUS_KEY = "jitterRadius"
private const val TARGET_SIZE_KEY = "targetSize"
private const val TARGET_X_KEY = "targetX"
private const val TARGET_Y_KEY = "targetY"
private const val CONTROL_X_KEY = "controlX"
private const val CONTROL_Y_KEY = "controlY"
private const val OVERLAY_SERVICE_RUNNING_KEY = "overlayServiceRunning"
const val CONFIGURATION_LIST_KEY = "configurationList"
const val OVERLAY_PREFERENCES_NAME = "floating_overlay"

data class OverlayConfig(
    // 标识当前悬浮点击使用的点击频率。
    val clicksPerSecond: Double = DEFAULT_CLICKS_PER_SECOND,
    // 标识当前悬浮点击使用的固定偏移。
    val jitterRadius: Double = DEFAULT_JITTER_RADIUS,
    // 标识当前准星显示尺寸。
    val targetSize: Double = DEFAULT_TARGET_SIZE,
    // 标识当前准星横向坐标。
    val targetX: Int = DEFAULT_TARGET_X,
    // 标识当前准星纵向坐标。
    val targetY: Int = DEFAULT_TARGET_Y,
) {
    // 标识将当前原生配置转换为 Flutter 侧统一消费的配置结构。
    fun toPreferenceMap(): Map<String, Double> {
        return mapOf(
            CLICKS_PER_SECOND_KEY to clicksPerSecond,
            JITTER_RADIUS_KEY to jitterRadius,
            TARGET_SIZE_KEY to targetSize,
            TARGET_X_KEY to targetX.toDouble(),
            TARGET_Y_KEY to targetY.toDouble(),
        )
    }

    // 标识将当前配置转换为配置列表持久化所需的 JSON 结构。
    fun toJson(id: String, name: String): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("name", name)
            put(CLICKS_PER_SECOND_KEY, clicksPerSecond)
            put(JITTER_RADIUS_KEY, jitterRadius)
            put(TARGET_SIZE_KEY, targetSize)
            put(TARGET_X_KEY, targetX)
            put(TARGET_Y_KEY, targetY)
        }
    }

    // 标识将当前配置写入悬浮服务启动参数，减少调用侧重复字段拼装。
    fun putExtras(intent: Intent) {
        intent.putExtra(CLICKS_PER_SECOND_KEY, clicksPerSecond)
        intent.putExtra(JITTER_RADIUS_KEY, jitterRadius)
        intent.putExtra(TARGET_SIZE_KEY, targetSize)
        intent.putExtra(TARGET_X_KEY, targetX.toDouble())
        intent.putExtra(TARGET_Y_KEY, targetY.toDouble())
    }

    fun saveToPreferences(
        preferences: SharedPreferences,
        controlPosition: OverlayPosition? = null,
    ) {
        preferences.edit().apply {
            putFloat(CLICKS_PER_SECOND_KEY, clicksPerSecond.toFloat())
            putFloat(JITTER_RADIUS_KEY, jitterRadius.toFloat())
            putFloat(TARGET_SIZE_KEY, targetSize.toFloat())
            putInt(TARGET_X_KEY, targetX)
            putInt(TARGET_Y_KEY, targetY)
            controlPosition?.let {
                putInt(CONTROL_X_KEY, it.x)
                putInt(CONTROL_Y_KEY, it.y)
            }
        }.apply()
    }

    companion object {
        // 标识当前原生层在未收到 Flutter 配置时的最小默认点击频率。
        const val DEFAULT_CLICKS_PER_SECOND = 8.0

        // 标识当前原生层在未收到 Flutter 配置时的最小默认点击偏移。
        const val DEFAULT_JITTER_RADIUS = 4.0

        // 标识当前原生层在未收到 Flutter 配置时的最小默认准星尺寸。
        const val DEFAULT_TARGET_SIZE = 64.0

        // 标识当前原生层在未收到 Flutter 配置时的最小默认准星横坐标。
        const val DEFAULT_TARGET_X = 180

        // 标识当前原生层在未收到 Flutter 配置时的最小默认准星纵坐标。
        const val DEFAULT_TARGET_Y = 300

        // 标识从本地偏好恢复原生悬浮配置。
        fun fromPreferences(preferences: SharedPreferences): OverlayConfig {
            return OverlayConfig(
                clicksPerSecond = preferences.readDouble(
                    CLICKS_PER_SECOND_KEY,
                    DEFAULT_CLICKS_PER_SECOND,
                ),
                jitterRadius = preferences.readDouble(
                    JITTER_RADIUS_KEY,
                    DEFAULT_JITTER_RADIUS,
                ),
                targetSize = preferences.readDouble(TARGET_SIZE_KEY, DEFAULT_TARGET_SIZE),
                targetX = preferences.getInt(TARGET_X_KEY, DEFAULT_TARGET_X),
                targetY = preferences.getInt(TARGET_Y_KEY, DEFAULT_TARGET_Y),
            )
        }

        // 标识从 Flutter 通道参数恢复原生悬浮配置。
        fun fromMethodCall(call: MethodCall): OverlayConfig {
            return OverlayConfig(
                clicksPerSecond =
                    call.argument<Double>(CLICKS_PER_SECOND_KEY) ?: DEFAULT_CLICKS_PER_SECOND,
                jitterRadius =
                    call.argument<Double>(JITTER_RADIUS_KEY) ?: DEFAULT_JITTER_RADIUS,
                targetSize = call.argument<Double>(TARGET_SIZE_KEY) ?: DEFAULT_TARGET_SIZE,
                targetX =
                    call.argument<Double>(TARGET_X_KEY)?.roundToInt() ?: DEFAULT_TARGET_X,
                targetY =
                    call.argument<Double>(TARGET_Y_KEY)?.roundToInt() ?: DEFAULT_TARGET_Y,
            )
        }

        // 标识合并 Intent 参数与本地持久化结果，恢复服务启动配置。
        fun fromIntent(intent: Intent?, preferences: SharedPreferences): OverlayConfig {
            val saved = fromPreferences(preferences)
            return OverlayConfig(
                clicksPerSecond =
                    intent?.getDoubleExtra(CLICKS_PER_SECOND_KEY, saved.clicksPerSecond)
                        ?: saved.clicksPerSecond,
                jitterRadius =
                    intent?.getDoubleExtra(JITTER_RADIUS_KEY, saved.jitterRadius)
                        ?: saved.jitterRadius,
                targetSize =
                    intent?.getDoubleExtra(TARGET_SIZE_KEY, saved.targetSize) ?: saved.targetSize,
                targetX =
                    intent?.getDoubleExtra(TARGET_X_KEY, saved.targetX.toDouble())
                        ?.roundToInt() ?: saved.targetX,
                targetY =
                    intent?.getDoubleExtra(TARGET_Y_KEY, saved.targetY.toDouble())
                        ?.roundToInt() ?: saved.targetY,
            )
        }

    }
}

data class OverlayPosition(val x: Int, val y: Int)

fun SharedPreferences.readDouble(key: String, fallback: Double): Double {
    return getFloat(key, fallback.toFloat()).toDouble()
}

fun SharedPreferences.readPosition(defaultX: Int, defaultY: Int): OverlayPosition {
    return OverlayPosition(
        x = getInt(CONTROL_X_KEY, defaultX),
        y = getInt(CONTROL_Y_KEY, defaultY),
    )
}

fun SharedPreferences.readOverlayServiceRunning(): Boolean {
    return getBoolean(OVERLAY_SERVICE_RUNNING_KEY, false)
}

fun SharedPreferences.setOverlayServiceRunning(running: Boolean) {
    edit().putBoolean(OVERLAY_SERVICE_RUNNING_KEY, running).apply()
}
