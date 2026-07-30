import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';
import '../models/driver_settings.dart';
import '../models/fare_result.dart';
import '../parser/parser_engine.dart';
import 'overlay_service.dart';
import 'storage_service.dart';

typedef FareCalculatedCallback = void Function(FareResult result);

class BackgroundServiceManager {
  // ── Native MethodChannel Bridge ───────────────────────────────────────────
  static const _channel = MethodChannel('com.ridebuddy/native_bridge');

  StreamSubscription? _notificationSub;
  Timer? _pollTimer;

  FareCalculatedCallback? onFareCalculated;
  bool isRunning = false;

  /// Check if the native Kotlin AccessibilityService is bound and active
  static Future<bool> isNativeServiceRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isNativeServiceRunning');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Check if accessibility permission is enabled (uses platform check)
  static Future<bool> isAccessibilityGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('isNativeServiceRunning');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Push current settings to the native service via SharedPreferences
  static Future<void> syncSettingsToNative(DriverSettings settings) async {
    try {
      await _channel.invokeMethod('saveSettings', {
        'uberCommission': settings.uberCommissionPercent,
        'pickmeCommission': settings.pickmeCommissionPercent,
        'helagoCommission': settings.helagoCommissionPercent,
        'targetPerKm': settings.targetProfitPerKm,
      });
    } catch (e) {
      debugPrint('[RideBuddy] Failed to sync settings to native: $e');
    }
  }

  /// Get the latest fare JSON captured by native service (null = none yet)
  static Future<String?> getLatestNativeFare() async {
    try {
      return await _channel.invokeMethod<String>('getLatestFare');
    } catch (_) {
      return null;
    }
  }

  /// Mark the latest fare as consumed so we don't show it twice
  static Future<void> clearLatestNativeFare() async {
    try {
      await _channel.invokeMethod('clearLatestFare');
    } catch (_) {}
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
      debugPrint('[RideBuddy] Error requesting notification permission: $e');
    }
  }

  /// Start background monitoring.
  ///
  /// Primary source: Native Kotlin AccessibilityService → SharedPreferences poll
  /// Secondary source: NotificationListenerService stream
  Future<void> startService(StorageService storageService) async {
    stopService();
    isRunning = true;

    final settings = storageService.getSettings();

    // Push settings to native service (used by Kotlin for commission calc)
    await syncSettingsToNative(settings);

    // ── 1. Poll SharedPreferences for results from native Kotlin service ──────
    // Native service writes results to SharedPreferences; we poll every 2s.
    // This works even when Flutter was killed and then resumed.
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!isRunning) return;
      await _pollNativeFare(storageService);
    });

    // ── 2. Notification Listener (secondary source) ───────────────────────────
    try {
      final isNotifGranted = await isNotificationListenerGranted();
      if (isNotifGranted) {
        _notificationSub = NotificationListenerService.notificationsStream
            .listen((ServiceNotificationEvent event) {
          if (!isRunning) return;

          final pkg = event.packageName ?? '';
          final lowerPkg = pkg.toLowerCase();

          // Never process RideBuddy's own notifications
          if (lowerPkg.contains('ridebuddy')) return;

          // Only target known driver apps
          const targetPkgs = ['ubercab', 'uber', 'pickme', 'helago'];
          final isTarget = targetPkgs.any((p) => lowerPkg.contains(p));
          if (!isTarget) return;

          final title = event.title ?? '';
          final content = event.content ?? '';
          final fullNotif = '$title $content'.trim();
          final lower = fullNotif.toLowerCase();

          // Must contain currency to be fare-related
          if (!lower.contains('lkr') && !lower.contains('rs.')) return;

          debugPrint('[RideBuddy Notification] ($pkg): $fullNotif');
          _processRawText(fullNotif, pkg, storageService);
        });
      }
    } catch (e) {
      debugPrint('[RideBuddy] Error initializing notification listener: $e');
    }
  }

  /// Poll SharedPreferences for any fare data written by native Kotlin service
  Future<void> _pollNativeFare(StorageService storageService) async {
    final fareJsonStr = await getLatestNativeFare();
    if (fareJsonStr == null || fareJsonStr.isEmpty) return;

    // Consume it immediately so we don't show it again
    await clearLatestNativeFare();

    // Parse the JSON into a FareResult
    try {
      final fareResult = _nativeFareJsonToResult(fareJsonStr, storageService);
      if (fareResult != null) {
        await _presentFareResult(fareResult, storageService);
      }
    } catch (e) {
      debugPrint('[RideBuddy] Error parsing native fare JSON: $e');
    }
  }

  FareResult? _nativeFareJsonToResult(String json, StorageService storage) {
    try {
      // Minimal JSON parsing without external dependency
      final map = _parseSimpleJson(json);
      final settings = storage.getSettings();

      final platform = map['platform'] as String? ?? 'Driver App';
      final grossFare = (map['grossFare'] as num?)?.toDouble() ?? 0.0;
      final pickupKm = (map['pickupKm'] as num?)?.toDouble() ?? 0.0;
      final tripKm = (map['tripKm'] as num?)?.toDouble() ?? 0.0;
      final commission = (map['commission'] as num?)?.toDouble() ?? 12.0;
      final rawText = map['rawText'] as String? ?? '';

      if (grossFare <= 0) return null;

      return FareResult(
        platform: platform,
        grossFare: grossFare,
        pickupDistanceKm: pickupKm,
        tripDistanceKm: tripKm,
        commissionPercent: commission,
        targetThresholdPerKm: settings.targetProfitPerKm,
        rawText: rawText,
      );
    } catch (e) {
      debugPrint('[RideBuddy] JSON parse error: $e');
      return null;
    }
  }

  /// Simple JSON key/value extractor (avoids dart:convert dependency issues in isolates)
  Map<String, dynamic> _parseSimpleJson(String json) {
    // Use dart:convert directly
    try {
      // ignore: avoid_dynamic_calls
      return const _JsonDecoder().convert(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  String? _lastCapturedFareKey;

  void _processRawText(String rawText, String packageName, StorageService storage) {
    final settings = storage.getSettings();
    final fareResult = ParserEngine.parse(
      rawText: rawText,
      packageName: packageName,
      settings: settings,
    );

    if (fareResult.grossFare > 0 &&
        fareResult.totalDistanceKm >= 0.2 &&
        fareResult.totalDistanceKm <= 200.0) {
      final fareKey =
          '${fareResult.platform}_${fareResult.grossFare.toStringAsFixed(0)}_${fareResult.totalDistanceKm.toStringAsFixed(1)}';

      if (_lastCapturedFareKey == fareKey) return;
      _lastCapturedFareKey = fareKey;

      _presentFareResult(fareResult, storage);
    }
  }

  Future<void> _presentFareResult(FareResult fareResult, StorageService storage) async {
    await storage.saveFareResult(fareResult);

    final settings = storage.getSettings();
    if (settings.autoShowOverlay) {
      await OverlayService.showProfitOverlay(fareResult);
    }

    onFareCalculated?.call(fareResult);
  }

  void stopService() {
    isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _notificationSub?.cancel();
    _notificationSub = null;
  }
}

// Lightweight JSON decoder helper
class _JsonDecoder {
  const _JsonDecoder();
  dynamic convert(String source) {
    // Delegate to dart:convert
    // ignore: prefer_function_declarations_over_variables
    return _decode(source);
  }
}

dynamic _decode(String source) {
  // We use dart:convert via import
  import 'dart:convert' as convert;
  return convert.jsonDecode(source);
}
