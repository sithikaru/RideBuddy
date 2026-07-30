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
import java.util.LinkedList

/**
 * RideBuddyAccessibilityService — Pure native Kotlin AccessibilityService.
 *
 * KEY DESIGN DECISIONS:
 *  - NO FlutterEngineCache dependency (that's what kills flutter_accessibility_service in background)
 *  - Runs completely independently of the Flutter engine lifecycle
 *  - Communicates results via SharedPreferences (Flutter reads on resume)
 *  - Posts a native Android heads-up notification for real-time alerts
 *  - Strictly filters its own package (com.ridebuddy.ridebuddy) to prevent spamming own UI text
 *  - Only triggers on WINDOW_CONTENT_CHANGED + WINDOW_STATE_CHANGED for efficiency
 */
class RideBuddyAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "RideBuddyA11y"
        const val PREFS_NAME = "ride_buddy_native_prefs"
        const val PREFS_KEY_LATEST_FARE = "latest_fare_json"
        const val PREFS_KEY_SERVICE_RUNNING = "native_service_running"
        const val CHANNEL_ID = "ridebuddy_fare_channel"
        const val NOTIF_ID = 9001

        // Target packages to monitor
        private val TARGET_PACKAGES = setOf(
            "com.ubercab.driver",
            "com.ubercab",
            "com.pickme.driver.byod",
            "com.pickme.driver",
            "lk.bhasha.helago.driver",
        )

        // Our own package — NEVER process these events
        private const val OWN_PACKAGE = "com.ridebuddy.ridebuddy"
    }

    // Deduplication: track last sent fare key to avoid spam
    private var lastFareKey: String? = null
    private var lastFareTime: Long = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "RideBuddyAccessibilityService connected successfully ✅")

        // Configure dynamically (belt + suspenders over static XML config)
        val info = serviceInfo ?: AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 300
        info.flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
        serviceInfo = info

        // Mark service as running in SharedPreferences
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putBoolean(PREFS_KEY_SERVICE_RUNNING, true)
            .apply()

        createNotificationChannel()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val pkg = event.packageName?.toString() ?: return

        // ── CRITICAL FILTER: Never read our own app's screen ──────────────────
        if (pkg == OWN_PACKAGE || pkg.contains("ridebuddy")) return

        // ── Only process target driver apps ───────────────────────────────────
        val isTargetPkg = TARGET_PACKAGES.any { pkg.contains(it) || it.contains(pkg) }
        if (!isTargetPkg) return

        // ── Extract text from this window's full node tree ───────────────────
        val root = rootInActiveWindow ?: return
        val texts = mutableListOf<String>()
        extractNodeTexts(root, texts, depth = 0, maxDepth = 25)
        root.recycle()

        if (texts.isEmpty()) return

        val fullText = texts.joinToString(" ")

        // Quick early reject: must contain a currency marker to be a fare screen
        val lower = fullText.lowercase()
        val hasCurrency = lower.contains("lkr") || lower.contains("rs.")
        if (!hasCurrency) return

        Log.d(TAG, "[$pkg] Captured text: ${fullText.take(200)}")

        // ── Parse fare data ──────────────────────────────────────────────────
        val platform = detectPlatform(pkg, lower)
        val grossFare = extractGrossFare(fullText)
        val distances = extractDistances(fullText)
        val pickupKm = distances["pickup"] ?: 0.0
        val tripKm = distances["trip"] ?: 0.0
        val totalKm = pickupKm + tripKm

        // Validate: must have a fare AND at least one distance
        if (grossFare <= 0.0 || totalKm < 0.3 || totalKm > 200.0) {
            Log.d(TAG, "Rejected: fare=$grossFare totalKm=$totalKm")
            return
        }

        // ── Deduplication ────────────────────────────────────────────────────
        val fareKey = "${platform}_${grossFare.toInt()}_${totalKm.format1}"
        val now = System.currentTimeMillis()
        if (fareKey == lastFareKey && (now - lastFareTime) < 30_000L) {
            return // Same fare within 30 seconds — skip
        }
        lastFareKey = fareKey
        lastFareTime = now

        // ── Read settings from SharedPreferences ─────────────────────────────
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

        Log.i(TAG, "✅ FARE: $platform Rs.$grossFare | ${totalKm.format1}km | Rs.${farePerKm.format1}/km | profitable=$isProfitable")

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

        // ── Show heads-up notification ────────────────────────────────────────
        showFareNotification(platform, grossFare, netFare, totalKm, farePerKm, isProfitable)
    }

    override fun onInterrupt() {
        Log.w(TAG, "RideBuddyAccessibilityService interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putBoolean(PREFS_KEY_SERVICE_RUNNING, false)
            .apply()
        Log.w(TAG, "RideBuddyAccessibilityService destroyed")
    }

    // ── Text Extraction ───────────────────────────────────────────────────────

    private fun extractNodeTexts(
        node: AccessibilityNodeInfo?,
        results: MutableList<String>,
        depth: Int,
        maxDepth: Int,
    ) {
        if (node == null || depth > maxDepth) return

        // Collect text or content description
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

    // ── Platform Detection ────────────────────────────────────────────────────

    private fun detectPlatform(pkg: String, lowerText: String): String {
        if (pkg.contains("ubercab") || pkg.contains("uber")) return "Uber"
        if (pkg.contains("pickme")) return "PickMe"
        if (pkg.contains("helago")) return "Helago"

        // Fallback: text signatures
        if (lowerText.contains("accept trip") ||
            lowerText.contains("trip scanner") ||
            Regex("[0-9.]+\\s*lkr").containsMatchIn(lowerText)
        ) return "PickMe"

        if (lowerText.contains("match") || lowerText.contains("total") ||
            Regex("lkr\\s*[0-9.]").containsMatchIn(lowerText)
        ) return "Uber"

        if (lowerText.contains("helago")) return "Helago"

        return "Driver App"
    }

    // ── Fare Extraction ───────────────────────────────────────────────────────

    private fun extractGrossFare(text: String): Double {
        val candidates = mutableListOf<Double>()

        // LKR prefix: LKR270.40, LKR 150, Rs. 850
        val prefixRe = Regex(
            """(?:LKR|Rs\.?|රු\.?|ரூ\.?)\s*([0-9]{1,5}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)""",
            RegexOption.IGNORE_CASE
        )
        prefixRe.findAll(text).forEach { m ->
            m.groupValues[1].replace(",", "").toDoubleOrNull()?.let { v ->
                if (v > 0 && v <= 50000) candidates.add(v)
            }
        }

        // LKR suffix: 893.48 LKR (PickMe format)
        val suffixRe = Regex(
            """([0-9]{1,5}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\s*(?:LKR|Rs\.?|රු\.?|ரூ\.?)""",
            RegexOption.IGNORE_CASE
        )
        suffixRe.findAll(text).forEach { m ->
            m.groupValues[1].replace(",", "").toDoubleOrNull()?.let { v ->
                if (v > 0 && v <= 50000) candidates.add(v)
            }
        }

        if (candidates.isEmpty()) return 0.0
        // The primary fare is the largest candidate (avoid picking up commission subvalues)
        return candidates.max()
    }

    // ── Distance Extraction ───────────────────────────────────────────────────

    private fun extractDistances(text: String): Map<String, Double> {
        var pickup = 0.0
        var trip = 0.0

        // Uber: "(1.9 km) away", "(3.2 km) trip", "(5.2 km) total"
        val awayRe = Regex("""\(([0-9]+(?:\.[0-9]+)?)\s*km\)\s*away""", RegexOption.IGNORE_CASE)
        val tripRe = Regex("""\(([0-9]+(?:\.[0-9]+)?)\s*km\)\s*trip""", RegexOption.IGNORE_CASE)
        val totalRe = Regex("""\(([0-9]+(?:\.[0-9]+)?)\s*km\)\s*total""", RegexOption.IGNORE_CASE)

        // PickMe: "(2mins away, 0.6 km)", "(6 min, 2.08 km)"
        val pickmeAwayRe = Regex(
            """away[,\s]+([0-9]+(?:\.[0-9]+)?)\s*km""", RegexOption.IGNORE_CASE
        )
        val pickmeTripRe = Regex(
            """\([0-9]+\s*min[s]?,\s*([0-9]+(?:\.[0-9]+)?)\s*km\)""", RegexOption.IGNORE_CASE
        )

        awayRe.find(text)?.groupValues?.getOrNull(1)?.toDoubleOrNull()?.let { v ->
            if (v in 0.1..150.0) pickup = v
        }
        pickmeAwayRe.find(text)?.groupValues?.getOrNull(1)?.toDoubleOrNull()?.let { v ->
            if (pickup == 0.0 && v in 0.1..150.0) pickup = v
        }

        tripRe.find(text)?.groupValues?.getOrNull(1)?.toDoubleOrNull()?.let { v ->
            if (v in 0.1..200.0) trip = v
        }
        pickmeTripRe.find(text)?.groupValues?.getOrNull(1)?.toDoubleOrNull()?.let { v ->
            if (trip == 0.0 && v in 0.1..200.0) trip = v
        }

        // If still empty, try "total" line and fallback generic km scan
        if (pickup == 0.0 && trip == 0.0) {
            totalRe.find(text)?.groupValues?.getOrNull(1)?.toDoubleOrNull()?.let { total ->
                if (total in 0.1..200.0) trip = total
            }
        }

        // Last resort: generic km numbers — assign first = pickup, second = trip
        if (pickup == 0.0 && trip == 0.0) {
            val genericKm = Regex("""([0-9]+(?:\.[0-9]+)?)\s*km\b""", RegexOption.IGNORE_CASE)
            val found = genericKm.findAll(text).mapNotNull { m ->
                m.groupValues[1].toDoubleOrNull()?.takeIf { it in 0.1..200.0 }
            }.toList()
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
                CHANNEL_ID,
                "RideBuddy Fare Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Real-time fare profit alerts"
                enableVibration(true)
                setShowBadge(true)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun showFareNotification(
        platform: String,
        grossFare: Double,
        netFare: Double,
        totalKm: Double,
        farePerKm: Double,
        isProfitable: Boolean,
    ) {
        val launchIntent = packageManager.getLaunchIntentForPackage(OWN_PACKAGE)
        val pi = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val emoji = if (isProfitable) "✅" else "⚠️"
        val title = "$emoji $platform — Rs.${farePerKm.format1}/km"
        val body = "Gross: Rs.${grossFare.format0} | Net: Rs.${netFare.format0} | ${totalKm.format1}km"

        val notif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setOnlyAlertOnce(false)
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, notif)
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private val Double.format0 get() = String.format("%.0f", this)
    private val Double.format1 get() = String.format("%.1f", this)
}
