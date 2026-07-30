import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/driver_settings.dart';
import '../models/fare_result.dart';

class StorageService {
  static const String _keySettings = 'driver_settings';
  static const String _keyDisclosureAccepted = 'prominent_disclosure_accepted';
  static const String _keyFareHistory = 'fare_history';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  /// Get stored driver settings or defaults
  DriverSettings getSettings() {
    final jsonStr = _prefs.getString(_keySettings);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        return DriverSettings.fromJson(jsonStr);
      } catch (_) {}
    }
    return const DriverSettings();
  }

  /// Save driver settings
  Future<bool> saveSettings(DriverSettings settings) async {
    return await _prefs.setString(_keySettings, settings.toJson());
  }

  /// Check if user has accepted Prominent Disclosure UI
  bool hasAcceptedDisclosure() {
    return _prefs.getBool(_keyDisclosureAccepted) ?? false;
  }

  /// Set Prominent Disclosure acceptance status
  Future<bool> setDisclosureAccepted(bool accepted) async {
    return await _prefs.setBool(_keyDisclosureAccepted, accepted);
  }

  /// Save recent fare result to history (keep max 50 items)
  Future<void> saveFareResult(FareResult result) async {
    final history = getFareHistory();
    history.insert(0, result);
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }
    final jsonList = history.map((e) => json.encode(e.toMap())).toList();
    await _prefs.setStringList(_keyFareHistory, jsonList);
  }

  /// Retrieve fare history
  List<FareResult> getFareHistory() {
    final jsonList = _prefs.getStringList(_keyFareHistory);
    if (jsonList == null || jsonList.isEmpty) return [];

    final List<FareResult> list = [];
    for (final str in jsonList) {
      try {
        list.add(FareResult.fromMap(json.decode(str)));
      } catch (_) {}
    }
    return list;
  }

  /// Clear fare history
  Future<bool> clearHistory() async {
    return await _prefs.remove(_keyFareHistory);
  }
}
