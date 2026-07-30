import 'package:flutter/material.dart';
import 'package:system_alert_window/system_alert_window.dart';
import '../models/fare_result.dart';

class OverlayService {
  static Future<bool> checkPermission() async {
    return await SystemAlertWindow.checkPermissions(
          prefMode: SystemWindowPrefMode.OVERLAY,
        ) ??
        false;
  }

  static Future<bool?> requestPermission() async {
    return await SystemAlertWindow.requestPermissions(
      prefMode: SystemWindowPrefMode.OVERLAY,
    );
  }

  /// Show or update the floating profit pill overlay window on screen.
  /// Uses non-focusable & non-touch-modal flags so touches pass through cleanly to driver apps.
  static Future<void> showProfitOverlay(FareResult fare) async {
    final hasPerm = await checkPermission();
    if (!hasPerm) {
      await requestPermission();
      return;
    }

    final String title = "${fare.platform}: ${fare.formattedFarePerKm}";
    final String body =
        "Net: ${fare.formattedNetFare} | Dist: ${fare.formattedTotalDistance}";

    await SystemAlertWindow.showSystemWindow(
      notificationTitle: title,
      notificationBody: body,
      height: 110,
      gravity: SystemWindowGravity.TOP,
      prefMode: SystemWindowPrefMode.OVERLAY,
      layoutParamFlags: [
        SystemWindowFlags.FLAG_NOT_FOCUSABLE,
        SystemWindowFlags.FLAG_NOT_TOUCH_MODAL,
      ],
    );

    // Auto-close overlay after 12 seconds so screen stays clean
    Future.delayed(const Duration(seconds: 12), () {
      closeOverlay();
    });
  }

  static Future<void> closeOverlay() async {
    try {
      await SystemAlertWindow.closeSystemWindow(
        prefMode: SystemWindowPrefMode.OVERLAY,
      );
    } catch (_) {}
  }
}
