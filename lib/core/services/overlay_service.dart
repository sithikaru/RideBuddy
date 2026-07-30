import 'package:flutter/material.dart';
import 'package:system_alert_window/system_alert_window.dart';
import '../models/fare_result.dart';

class OverlayService {
  static Future<bool> checkPermission() async {
    return await SystemAlertWindow.checkPermissions() ?? false;
  }

  static Future<bool?> requestPermission() async {
    return await SystemAlertWindow.requestPermissions();
  }

  /// Show or update the floating profit pill overlay window on screen
  static Future<void> showProfitOverlay(FareResult fare) async {
    final hasPerm = await checkPermission();
    if (!hasPerm) return;

    final String title = "${fare.platform}: ${fare.formattedFarePerKm}";
    final String body =
        "Net: ${fare.formattedNetFare} | Dist: ${fare.formattedTotalDistance}";

    await SystemAlertWindow.showSystemWindow(
      notificationTitle: title,
      notificationBody: body,
      height: 110,
      gravity: SystemWindowGravity.TOP,
      prefMode: SystemWindowPrefMode.OVERLAY,
    );
  }

  static Future<void> closeOverlay() async {
    await SystemAlertWindow.closeSystemWindow();
  }
}

