package com.ridebuddy.ridebuddy

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject

/**
 * RideBuddyAccessibilityService — Pure native Kotlin AccessibilityService.
 *
 * Monitors ONLY driver apps for fare offers. Completely independent of Flutter.
 * Writes fare results to SharedPreferences; Flutter reads on resume via MethodChannel.
 */
class RideBuddyAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "RideBuddyA11y"
        const val PREFS_NAME = "ride_buddy_native_prefs"
        const val PREFS_KEY_LATEST_FARE = "latest_fare_json"
        const val PREFS_KEY_SERVICE_RUNNING = "native_service_running"
        const val CHANNEL_ID = "ridebuddy_fare_channel"
        const val NOTIF_ID = 9001

        // ── EXACT package names confirmed from device via `adb shell pm list packages` ──
        // Separate rider apps from driver apps — we ONLY want driver apps!
        val TARGET_DRIVER_PACKAGES = setOf(
            "com.ubercab.driver",       // Uber Driver
            "com.pickme.driver.byod",   // PickMe Driver (BYOD)
            "lk.bhasha.helago.driver",  // Helago Driver
        )

        // Rider apps — NOT targets (driver doesn't use these for fare offers)
        // "com.ubercab"           ← Uber rider app  (skip)
        // "com.pickme.passenger"  ← PickMe rider app (skip)

        private const val OWN_PACKAGE = "com.ridebuddy.ridebuddy"
    }

    private var lastFareKey: String? = null
    private var lastFareTime: Long = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "✅ RideBuddyAccessibilityService CONNECTED")

        val info = serviceInfo ?: AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 300
        info.flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
        // NOTE: Do NOT set packageNames here — let all events through, filter in code
        serviceInfo = info

        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putBoolean(PREFS_KEY_SERVICE_RUNNING, true)
            .apply()

        createNotificationChannel()
        Log.i(TAG, "Monitoring driver packages: $TARGET_DRIVER_PACKAGES")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val pkg = event.packageName?.toString() ?: return

        // ── FILTER 1: Block our own app ──────────────────────────────────────
        if (pkg == OWN_PACKAGE) return

        // ── FILTER 2: Only process known driver apps ─────────────────────────
        if (!TARGET_DRIVER_PACKAGES.contains(pkg)) return

        Log.d(TAG, "Event from $pkg type=${event.eventType}")

        // ── Extract all text from the entire window tree ─────────────────────
        val root = rootInActiveWindow
        if (root == null) {
            Log.d(TAG, "rootInActiveWindow is null for $pkg")
            return
        }

        val texts = mutableListOf<String>()
        extractNodeTexts(root, texts, depth = 0, maxDepth = 30)
        root.recycle()

        if (texts.isEmpty()) return

        val fullText = texts.joinToString(" ")
        val lower = fullText.lowercase()

        // ── FILTER 3: Must have a currency marker ────────────────────────────
        if (!lower.contains("lkr") && !lower.contains("rs.") && !lower.contains("rs ")) {
            return
        }

        Log.i(TAG, "[$pkg] Text captured (${fullText.length} chars): ${fullText.take(300)}")

        // ── Parse ────────────────────────────────────────────────────────────
        val platform = detectPlatform(pkg, lower)
        val grossFare = extractGrossFare(fullText)
        val distances = extractDistances(fullText)
        val pickupKm = distances["pickup"] ?: 0.0
        val tripKm = distances["trip"] ?: 0.0
        val totalKm = pickupKm + tripKm

        if (grossFare <= 0.0) {
            Log.d(TAG, "No fare found in text")
            return
        }

        if (totalKm < 0.3 || totalKm > 200.0) {
            Log.d(TAG, "Implausible distance: ${totalKm}km — skipping")
            return
        }

        // ── Deduplication (same fare within 30s = skip) ──────────────────────
        val fareKey = "${platform}_${grossFare.toInt()}_${String.format("%.1f", totalKm)}"
        val now = System.currentTimeMillis()
        if (fareKey == lastFareKey && (now - lastFareTime) < 30_000L) {
            return
        }
        lastFareKey = fareKey
        lastFareTime = now

        // ── Load settings from SharedPreferences ─────────────────────────────
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val uberCommission = prefs.getFloat("uber_commission", 10.0f).toDouble()
        val pickmeCommission = prefs.getFloat("pickme_commission", 15.0f).toDouble()
        val helagoCommission = prefs.getFloat("helago_commission", 12.0f).toDouble()
        val targetPerKm = prefs.getFloat("target_per_km", 60.0f).toDouble()

        val commission = when (platform) {
            "Uber" -> uberCommission
            "PickMe" -> pickmeCommission
            "Helago" -> helagoCommission
            else -> 12.0
        }

        val netFare = grossFare * (1.0 - commission / 100.0)
        val farePerKm = if (totalKm > 0) netFare / totalKm else 0.0
        val isProfitable = farePerKm >= targetPerKm

        Log.i(TAG, "✅ FARE RESULT: $platform Rs.${String.format("%.0f",grossFare)} | " +
                "${String.format("%.1f",totalKm)}km | " +
                "Rs.${String.format("%.1f",farePerKm)}/km | profitable=$isProfitable")

        // ── Save to SharedPreferences for Flutter to read ────────────────────
        val fareJson = JSONObject().apply {
            put("platform", platform)
            put("grossFare", grossFare)
            put("pickupKm", pickupKm)
            put("tripKm", tripKm)
            put("totalKm", totalKm)
            put("netFare", netFare)
            put("farePerKm", farePerKm)
            put("isProfitable", isProfitable)
            put("commission", commission)
            put("targetPerKm", targetPerKm)
            put("rawText", fullText.take(500))
            put("timestamp", System.currentTimeMillis())
        }.toString()

        prefs.edit().putString(PREFS_KEY_LATEST_FARE, fareJson).apply()

        // ── Post heads-up notification ────────────────────────────────────────
        showFareNotification(platform, grossFare, netFare, totalKm, farePerKm, isProfitable)
    }

    override fun onInterrupt() {
        Log.w(TAG, "Service interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putBoolean(PREFS_KEY_SERVICE_RUNNING, false).apply()
        Log.w(TAG, "Service destroyed")
    }

    // ── Text extraction ───────────────────────────────────────────────────────

    private fun extractNodeTexts(
        node: AccessibilityNodeInfo?,
        results: MutableList<String>,
        depth: Int,
        maxDepth: Int,
    ) {
        if (node == null || depth > maxDepth) return

        val txt = node.text?.toString()?.trim()
        if (!txt.isNullOrEmpty() && txt != "null") {
            results.add(txt)
        } else {
            val desc = node.contentDescription?.toString()?.trim()
            if (!desc.isNullOrEmpty() && desc != "null") {
                results.add(desc)
            }
        }

        for (i in 0 until node.childCount) {
            extractNodeTexts(node.getChild(i), results, depth + 1, maxDepth)
        }
    }

    // ── Platform detection ────────────────────────────────────────────────────

    private fun detectPlatform(pkg: String, lowerText: String): String {
        // Package is the most reliable signal
        return when (pkg) {
            "com.ubercab.driver" -> "Uber"
            "com.pickme.driver.byod" -> "PickMe"
            "lk.bhasha.helago.driver" -> "Helago"
            else -> "Driver App"
        }
    }

    // ── Fare extraction ───────────────────────────────────────────────────────

    private fun extractGrossFare(text: String): Double {
        val candidates = mutableListOf<Double>()

        // LKR prefix formats: "LKR270.40", "LKR 150", "Rs. 850", "Rs 500"
        Regex(
            """(?:LKR|Rs\.?|රු\.?|ரூ\.?)\s*([0-9]{1,5}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)""",
            RegexOption.IGNORE_CASE
        ).findAll(text).forEach { m ->
            m.groupValues[1].replace(",", "").toDoubleOrNull()?.let { v ->
                if (v in 50.0..50000.0) candidates.add(v)
            }
        }

        // LKR suffix format: "893.48 LKR" (PickMe)
        Regex(
            """([0-9]{1,5}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\s*(?:LKR|Rs\.?|රු\.?|ரூ\.?)""",
            RegexOption.IGNORE_CASE
        ).findAll(text).forEach { m ->
            m.groupValues[1].replace(",", "").toDoubleOrNull()?.let { v ->
                if (v in 50.0..50000.0) candidates.add(v)
            }
        }

        if (candidates.isEmpty()) return 0.0
        return candidates.max() // Primary fare = largest value found
    }

    // ── Distance extraction ───────────────────────────────────────────────────

    private fun extractDistances(text: String): Map<String, Double> {
        var pickup = 0.0
        var trip = 0.0

        // Uber format: "(1.9 km) away", "(3.2 km) trip", "(5.2 km) total"
        Regex("""\(([0-9]+(?:\.[0-9]+)?)\s*km\)\s*away""", RegexOption.IGNORE_CASE)
            .find(text)?.groupValues?.getOrNull(1)?.toDoubleOrNull()?.let { v ->
                if (v in 0.1..150.0) pickup = v
            }

        Regex("""\(([0-9]+(?:\.[0-9]+)?)\s*km\)\s*trip""", RegexOption.IGNORE_CASE)
            .find(text)?.groupValues?.getOrNull(1)?.toDoubleOrNull()?.let { v ->
                if (v in 0.1..200.0) trip = v
            }

        // PickMe format: "away, 0.6 km", "(6 min, 2.08 km)"
        if (pickup == 0.0) {
            Regex("""away[,\s]+([0-9]+(?:\.[0-9]+)?)\s*km""", RegexOption.IGNORE_CASE)
                .find(text)?.groupValues?.getOrNull(1)?.toDoubleOrNull()?.let { v ->
                    if (v in 0.1..150.0) pickup = v
                }
        }

        if (trip == 0.0) {
            Regex("""\([0-9]+\s*min[s]?,\s*([0-9]+(?:\.[0-9]+)?)\s*km\)""", RegexOption.IGNORE_CASE)
                .find(text)?.groupValues?.getOrNull(1)?.toDoubleOrNull()?.let { v ->
                    if (v in 0.1..200.0) trip = v
                }
        }

        // Total fallback
        if (pickup == 0.0 && trip == 0.0) {
            Regex("""\(([0-9]+(?:\.[0-9]+)?)\s*km\)\s*total""", RegexOption.IGNORE_CASE)
                .find(text)?.groupValues?.getOrNull(1)?.toDoubleOrNull()?.let { v ->
                    if (v in 0.1..200.0) trip = v
                }
        }

        // Last resort: all bare km numbers
        if (pickup == 0.0 && trip == 0.0) {
            val found = Regex("""(?<!\()\b([0-9]+(?:\.[0-9]+)?)\s*km\b""", RegexOption.IGNORE_CASE)
                .findAll(text)
                .mapNotNull { m -> m.groupValues[1].toDoubleOrNull()?.takeIf { it in 0.1..200.0 } }
                .toList()
            when {
                found.size >= 2 -> { pickup = found[0]; trip = found[1] }
                found.size == 1 -> trip = found[0]
            }
        }

        return mapOf("pickup" to pickup, "trip" to trip)
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "RideBuddy Fare Alerts", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Real-time fare profit alerts"
                enableVibration(true)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun showFareNotification(
        platform: String, grossFare: Double, netFare: Double,
        totalKm: Double, farePerKm: Double, isProfitable: Boolean,
    ) {
        val pi = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(OWN_PACKAGE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val emoji = if (isProfitable) "✅" else "⚠️"
        val title = "$emoji $platform — Rs.${String.format("%.1f", farePerKm)}/km"
        val body = "Gross: Rs.${String.format("%.0f", grossFare)} | Net: Rs.${String.format("%.0f", netFare)} | ${String.format("%.1f", totalKm)}km"

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }

        val notif = builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()

        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIF_ID, notif)
    }
}
