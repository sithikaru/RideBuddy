import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';
import '../models/driver_settings.dart';
import '../models/fare_result.dart';
import '../parser/parser_engine.dart';
import 'overlay_service.dart';
import 'storage_service.dart';

typedef FareCalculatedCallback = void Function(FareResult result);

class BackgroundServiceManager {
  static final List<String> targetPackages = [
    'com.ubercab.driver',
    'com.pickme.driver',
    'com.helago.driver',
  ];

  StreamSubscription? _accessibilitySub;
  StreamSubscription? _notificationSub;

  FareCalculatedCallback? onFareCalculated;

  /// Check accessibility service permission state
  static Future<bool> isAccessibilityGranted() async {
    try {
      return await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Request accessibility service permission
  static Future<void> requestAccessibilityPermission() async {
    try {
      await FlutterAccessibilityService.requestAccessibilityPermission();
    } catch (e) {
      debugPrint("Error requesting accessibility permission: $e");
    }
  }

  /// Check notification listener permission state
  static Future<bool> isNotificationListenerGranted() async {
    try {
      return await NotificationListenerService.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  /// Request notification listener permission
  static Future<void> requestNotificationListenerPermission() async {
    try {
      await NotificationListenerService.requestPermission();
    } catch (e) {
      debugPrint("Error requesting notification permission: $e");
    }
  }

  /// Start background monitoring for screen text and notifications
  Future<void> startService(StorageService storageService) async {
    stopService();

    // 1. Accessibility Event Listener
    try {
      final isGranted = await isAccessibilityGranted();
      if (isGranted) {
        _accessibilitySub = FlutterAccessibilityService.accessStream.listen((event) {
          final pkg = event.packageName ?? '';
          final combinedText = _extractAllText(event);

          if (combinedText.isEmpty) return;

          // Battery Optimization: Only parse target ride hailing packages
          final isTargetApp = targetPackages.any((p) => pkg.toLowerCase().contains(p)) ||
              combinedText.toLowerCase().contains('uber') ||
              combinedText.toLowerCase().contains('pickme') ||
              combinedText.toLowerCase().contains('helago');

          if (!isTargetApp) return;

          _processRawText(combinedText, pkg, storageService);
        });
      }
    } catch (e) {
      debugPrint("Error initializing accessibility listener: $e");
    }

    // 2. Notification Listener Fallback
    try {
      final isNotifGranted = await isNotificationListenerGranted();
      if (isNotifGranted) {
        _notificationSub = NotificationListenerService.notificationsStream.listen((ServiceNotificationEvent event) {
          final pkg = event.packageName ?? '';
          final title = event.title ?? '';
          final content = event.content ?? '';
          final fullNotif = "$title $content";

          final isTargetPkg = targetPackages.any((p) => pkg.toLowerCase().contains(p)) ||
              fullNotif.toLowerCase().contains('uber') ||
              fullNotif.toLowerCase().contains('pickme') ||
              fullNotif.toLowerCase().contains('helago');

          if (isTargetPkg) {
            _processRawText(fullNotif, pkg, storageService);
          }
        });
      }
    } catch (e) {
      debugPrint("Error initializing notification listener: $e");
    }
  }

  static String _extractAllText(AccessibilityEvent event) {
    final List<String> texts = [];
    if (event.text != null && event.text!.isNotEmpty && event.text != 'null') {
      texts.add(event.text!);
    }
    if (event.subNodes != null) {
      for (final child in event.subNodes!) {
        final childText = _extractAllText(child);
        if (childText.isNotEmpty) {
          texts.add(childText);
        }
      }
    }
    return texts.join(' ');
  }

  void _processRawText(String rawText, String packageName, StorageService storage) async {
    final settings = storage.getSettings();
    final fareResult = ParserEngine.parse(
      rawText: rawText,
      packageName: packageName,
      settings: settings,
    );

    // Only present overlay and record if fare or distance was extracted
    if (fareResult.grossFare > 0 || fareResult.totalDistanceKm > 0) {
      await storage.saveFareResult(fareResult);

      if (settings.autoShowOverlay) {
        await OverlayService.showProfitOverlay(fareResult);
      }

      onFareCalculated?.call(fareResult);
    }
  }

  void stopService() {
    _accessibilitySub?.cancel();
    _accessibilitySub = null;
    _notificationSub?.cancel();
    _notificationSub = null;
  }
}
