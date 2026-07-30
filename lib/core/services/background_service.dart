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
    'ubercab',
    'uber',
    'pickme',
    'helago',
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

          final lowerPkg = pkg.toLowerCase();
          final lowerText = combinedText.toLowerCase();

          final isTargetPkg = targetPackages.any((p) => lowerPkg.contains(p));
          final hasRideKeywords = lowerText.contains('lkr') ||
              lowerText.contains('rs') ||
              lowerText.contains('km') ||
              lowerText.contains('away') ||
              lowerText.contains('trip') ||
              lowerText.contains('total') ||
              lowerText.contains('match') ||
              lowerText.contains('accept');

          if (isTargetPkg || hasRideKeywords) {
            debugPrint("[RideBuddy Accessibility Captured] ($pkg): $combinedText");
            _processRawText(combinedText, pkg, storageService);
          }
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

          final lowerPkg = pkg.toLowerCase();
          final lowerText = fullNotif.toLowerCase();

          final isTargetPkg = targetPackages.any((p) => lowerPkg.contains(p));
          final hasRideKeywords = lowerText.contains('lkr') ||
              lowerText.contains('rs') ||
              lowerText.contains('away') ||
              lowerText.contains('trip');

          if (isTargetPkg || hasRideKeywords) {
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
        if (child.text != null && child.text!.isNotEmpty && child.text != 'null') {
          texts.add(child.text!);
        }
      }
    }
    return texts.join(' ');
  }

  String? _lastCapturedFareKey;

  void _processRawText(String rawText, String packageName, StorageService storage) async {
    final settings = storage.getSettings();
    final fareResult = ParserEngine.parse(
      rawText: rawText,
      packageName: packageName,
      settings: settings,
    );

    // Only present overlay and record if BOTH valid gross fare AND realistic distance are extracted
    if (fareResult.grossFare > 0 &&
        fareResult.totalDistanceKm >= 0.2 &&
        fareResult.totalDistanceKm <= 200.0) {
      final fareKey =
          "${fareResult.platform}_${fareResult.grossFare.toStringAsFixed(0)}_${fareResult.totalDistanceKm.toStringAsFixed(1)}";
      
      // Prevent spamming identical calculations 50 times per second
      if (_lastCapturedFareKey == fareKey) return;
      _lastCapturedFareKey = fareKey;

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
