# System Instructions: Project "RideBuddy"
**Version:** 1.0.0
**Target OS:** Android Only (iOS explicitly unsupported due to sandboxing constraints)
**Framework:** Flutter
**Primary Purpose:** A background utility for gig-economy drivers (Uber, PickMe, Helago) that calculates real-time net profit per kilometer using screen and notification data, displaying the result in a system overlay without violating Google Play Store policies.

---

## 1. Development Environment & Architecture
As a solo developer, maintain a clean, modular architecture to manage background services efficiently. 
*   **Host Environment:** Apple Silicon (M3) macOS. Ensure Android Emulator is running the ARM64 system image for optimal performance during local debugging.
*   **State Management:** Riverpod or Bloc (keep UI strictly separated from the background service logic).
*   **Data Processing:** 100% Local. No data leaves the device. Do not integrate Firebase Analytics or Crashlytics for the background scraper to ensure absolute privacy compliance.

### Core Dependencies (`pubspec.yaml`)
*   `flutter_accessibility_service`: For reading the view hierarchy (screen nodes).
*   `flutter_overlay_window` (or `system_alert_window`): For drawing the floating profit UI over ride-hailing apps.
*   `notification_listener_service`: Fallback for capturing ride requests via Android notifications.
*   `shared_preferences` (or `isar`): For storing driver settings (commission rates, target profit per km).
*   `permission_handler`: For managing system-level permission requests.

---

## 2. Google Play Store Compliance (CRITICAL)
Any deviation from these rules will result in a Google Play Store rejection or account ban.

1.  **Accessibility Tool Flag:** In `AndroidManifest.xml`, strictly set `isAccessibilityTool="false"`. Antigravity is a utility, not a disability aid.
2.  **Prominent Disclosure:** Before invoking the system permission dialog, the app MUST display a custom UI screen stating:
    *   *What:* "Antigravity collects screen text and notification data from Uber, PickMe, and Helago."
    *   *Why:* "This is required to calculate your net fare and display profitable routes in a floating window."
    *   *Action:* Must have a clear "Accept & Continue" button.
3.  **No Autonomous Actions:** Antigravity must **never** auto-click, auto-accept, or auto-reject rides. It is strictly a read-only and calculation tool.
4.  **Local Execution:** All Regex parsing and data extraction must happen on the device.

---

## 3. Core Modules & Logic

### Module A: The Scraper Engine (Background Service)
The app must run a Foreground Service with a persistent notification (e.g., "Antigravity is monitoring fares") to prevent Android from aggressively killing the process.

*   **Target Packages:** 
    *   `com.ubercab.driver`
    *   `com.pickme.driver` (Verify exact package name)
    *   Helago driver package (Verify exact package name)
*   **Accessibility Listener:** Listen for `AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED`. Filter events strictly by the target package names to conserve battery.
*   **Notification Listener:** Listen for push notifications from the target packages. Extract the `title` and `body` strings.

### Module B: The Parsing & Math Matrix
Once text nodes or notifications are captured, pass them to the extraction engine.

**1. Extraction (Regex):**
*   Regex must account for LKR formatting (e.g., "Rs. 500", "LKR 1,200.00").
*   Regex must capture distance (e.g., "2.5 km", "800 m").
*   Variables required: `GrossFare`, `PickupDistance`, `TripDistance`.

**2. The Calculation:**
*   `TotalDistance` = `PickupDistance` + `TripDistance`
*   `PlatformDeduction` = `GrossFare` * (Platform Commission % / 100)
*   `NetFare` = `GrossFare` - `PlatformDeduction`
*   **`FarePerKm`** = `NetFare` / `TotalDistance`

### Module C: The Overlay UI (System Alert Window)
Trigger the overlay ONLY when a ride request is detected. 
*   **Design:** A small, non-intrusive pill or bubble that floats near the top or bottom edge of the screen, ensuring it does not block the "Accept/Reject" buttons of the underlying app.
*   **Data Displayed:** 
    *   Total Distance (e.g., 5.2 km)
    *   Net Fare (e.g., Rs. 450)
    *   **Per KM Rate** (e.g., Rs. 86/km)
*   **Visual Indicators:**
    *   🟢 Green: High profit (FarePerKm > Driver's target threshold)
    *   🟡 Yellow: Moderate profit
    *   🔴 Red: Loss/Low profit (FarePerKm < Driver's target threshold)

### Module D: Driver Configuration UI (Main App)
When the driver opens the actual Antigravity app, they should see:
1.  **Permission Dashboard:** Status indicators showing if Accessibility, Notification, and Overlay permissions are granted.
2.  **Platform Settings:** Input fields to set current commission percentages (e.g., Uber = 10%, PickMe = 15%). These change often, so the driver must be able to update them manually.
3.  **Target Goal:** An input field to set their desired minimum earnings per kilometer (e.g., Rs. 100/km) which drives the Red/Yellow/Green logic.
4.  **Battery Optimization Instructions:** A dedicated screen guiding the driver to their phone's settings to exclude Antigravity from battery-saving restrictions (Don't kill in background).

---

## 4. Error Handling & Edge Cases
*   **Missing Variables:** If the scraper misses a variable (e.g., Uber hides the pickup distance), the overlay should gracefully display "N/A" rather than crashing the background service.
*   **Currency/Metric Shifts:** Handle anomalies like "m" instead of "km" (convert meters to kilometers before calculating).
*   **App UI Updates:** The ride-hailing apps frequently update their UI. Design the Regex parsers to be injected remotely (e.g., via a simple remote JSON file hosted on a basic server) so parsers can be updated without requiring a full Play Store app update.