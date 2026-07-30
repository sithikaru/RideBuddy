import 'dart:convert';

/// Represents configurable driver settings for ride-hailing platforms and profit goals.
class DriverSettings {
  final double uberCommissionPercent;
  final double pickmeCommissionPercent;
  final double helagoCommissionPercent;
  final double targetProfitPerKm; // in LKR (e.g. 100.0)
  final bool autoShowOverlay;

  const DriverSettings({
    this.uberCommissionPercent = 10.0,
    this.pickmeCommissionPercent = 15.0,
    this.helagoCommissionPercent = 12.0,
    this.targetProfitPerKm = 100.0,
    this.autoShowOverlay = true,
  });

  DriverSettings copyWith({
    double? uberCommissionPercent,
    double? pickmeCommissionPercent,
    double? helagoCommissionPercent,
    double? targetProfitPerKm,
    bool? autoShowOverlay,
  }) {
    return DriverSettings(
      uberCommissionPercent: uberCommissionPercent ?? this.uberCommissionPercent,
      pickmeCommissionPercent: pickmeCommissionPercent ?? this.pickmeCommissionPercent,
      helagoCommissionPercent: helagoCommissionPercent ?? this.helagoCommissionPercent,
      targetProfitPerKm: targetProfitPerKm ?? this.targetProfitPerKm,
      autoShowOverlay: autoShowOverlay ?? this.autoShowOverlay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uberCommissionPercent': uberCommissionPercent,
      'pickmeCommissionPercent': pickmeCommissionPercent,
      'helagoCommissionPercent': helagoCommissionPercent,
      'targetProfitPerKm': targetProfitPerKm,
      'autoShowOverlay': autoShowOverlay,
    };
  }

  factory DriverSettings.fromMap(Map<String, dynamic> map) {
    return DriverSettings(
      uberCommissionPercent: (map['uberCommissionPercent'] as num?)?.toDouble() ?? 10.0,
      pickmeCommissionPercent: (map['pickmeCommissionPercent'] as num?)?.toDouble() ?? 15.0,
      helagoCommissionPercent: (map['helagoCommissionPercent'] as num?)?.toDouble() ?? 12.0,
      targetProfitPerKm: (map['targetProfitPerKm'] as num?)?.toDouble() ?? 100.0,
      autoShowOverlay: (map['autoShowOverlay'] as bool?) ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory DriverSettings.fromJson(String source) =>
      DriverSettings.fromMap(json.decode(source) as Map<String, dynamic>);
}
