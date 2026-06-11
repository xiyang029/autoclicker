package com.example.autoclicker

import android.content.Intent
import android.content.SharedPreferences
import io.flutter.plugin.common.MethodCall
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.roundToInt

private const val CLICKS_PER_SECOND_KEY = "clicksPerSecond"
private const val JITTER_RADIUS_KEY = "jitterRadius"
private const val TARGET_SIZE_KEY = "targetSize"
private const val TARGET_X_KEY = "targetX"
private const val TARGET_Y_KEY = "targetY"
private const val CONTROL_X_KEY = "controlX"
private const val CONTROL_Y_KEY = "controlY"
const val CONFIGURATION_LIST_KEY = "configurationList"
const val OVERLAY_PREFERENCES_NAME = "floating_overlay"

data class OverlayConfig(
    val clicksPerSecond: Double = DEFAULT_CLICKS_PER_SECOND,
    val jitterRadius: Double = DEFAULT_JITTER_RADIUS,
    val targetSize: Double = DEFAULT_TARGET_SIZE,
    val targetX: Int = DEFAULT_TARGET_X,
    val targetY: Int = DEFAULT_TARGET_Y,
) {
    fun toPreferenceMap(): Map<String, Double> {
        return mapOf(
            CLICKS_PER_SECOND_KEY to clicksPerSecond,
            JITTER_RADIUS_KEY to jitterRadius,
            TARGET_SIZE_KEY to targetSize,
            TARGET_X_KEY to targetX.toDouble(),
            TARGET_Y_KEY to targetY.toDouble(),
        )
    }

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
        const val DEFAULT_CLICKS_PER_SECOND = 8.0
        const val DEFAULT_JITTER_RADIUS = 6.0
        const val DEFAULT_TARGET_SIZE = 32.0
        const val DEFAULT_TARGET_X = 180
        const val DEFAULT_TARGET_Y = 300

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

        fun fromJson(json: JSONObject): OverlayConfig {
            return OverlayConfig(
                clicksPerSecond =
                    json.optDouble(CLICKS_PER_SECOND_KEY, DEFAULT_CLICKS_PER_SECOND),
                jitterRadius = json.optDouble(JITTER_RADIUS_KEY, DEFAULT_JITTER_RADIUS),
                targetSize = json.optDouble(TARGET_SIZE_KEY, DEFAULT_TARGET_SIZE),
                targetX = json.optInt(TARGET_X_KEY, DEFAULT_TARGET_X),
                targetY = json.optInt(TARGET_Y_KEY, DEFAULT_TARGET_Y),
            )
        }

        fun listFromPreferences(preferences: SharedPreferences, key: String): List<JSONObject> {
            val saved = preferences.getString(key, null).orEmpty()
            if (saved.isBlank()) {
                return emptyList()
            }

            val array = JSONArray(saved)
            return List(array.length(), array::getJSONObject)
        }

        fun saveListToPreferences(
            preferences: SharedPreferences,
            key: String,
            items: List<JSONObject>,
        ) {
            preferences.edit().putString(key, JSONArray(items).toString()).apply()
        }
    }
}

data class OverlayPosition(val x: Int, val y: Int)

fun SharedPreferences.readDouble(key: String, fallback: Double): Double {
    return getFloat(key, fallback.toFloat()).toDouble()
}

fun SharedPreferences.readPosition(): OverlayPosition {
    return OverlayPosition(
        x = getInt(CONTROL_X_KEY, 0),
        y = getInt(CONTROL_Y_KEY, 0),
    )
}

fun SharedPreferences.readPosition(defaultX: Int, defaultY: Int): OverlayPosition {
    return OverlayPosition(
        x = getInt(CONTROL_X_KEY, defaultX),
        y = getInt(CONTROL_Y_KEY, defaultY),
    )
}
