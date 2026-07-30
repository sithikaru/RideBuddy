package com.ridebuddy.ridebuddy

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.ridebuddy/native_bridge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Flutter asks: is the native accessibility service running?
                "isNativeServiceRunning" -> {
                    val prefs = getSharedPreferences(RideBuddyAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
                    result.success(prefs.getBoolean(RideBuddyAccessibilityService.PREFS_KEY_SERVICE_RUNNING, false))
                }

                // Flutter asks: get the latest fare JSON captured by native service
                "getLatestFare" -> {
                    val prefs = getSharedPreferences(RideBuddyAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
                    val fareJson = prefs.getString(RideBuddyAccessibilityService.PREFS_KEY_LATEST_FARE, null)
                    result.success(fareJson)
                }

                // Flutter asks: clear the latest fare (after it has been read and shown)
                "clearLatestFare" -> {
                    getSharedPreferences(RideBuddyAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
                        .edit().remove(RideBuddyAccessibilityService.PREFS_KEY_LATEST_FARE).apply()
                    result.success(null)
                }

                // Flutter saves settings for native service to use
                "saveSettings" -> {
                    val uberCommission = call.argument<Double>("uberCommission") ?: 10.0
                    val pickmeCommission = call.argument<Double>("pickmeCommission") ?: 15.0
                    val helagoCommission = call.argument<Double>("helagoCommission") ?: 12.0
                    val targetPerKm = call.argument<Double>("targetPerKm") ?: 60.0

                    getSharedPreferences(RideBuddyAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .putFloat("uber_commission", uberCommission.toFloat())
                        .putFloat("pickme_commission", pickmeCommission.toFloat())
                        .putFloat("helago_commission", helagoCommission.toFloat())
                        .putFloat("target_per_km", targetPerKm.toFloat())
                        .apply()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
