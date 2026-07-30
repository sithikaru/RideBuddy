import 'package:flutter/material.dart';

enum ProfitLevel { high, moderate, low, unknown }

class FareResult {
  final String platform;
  final double grossFare;
  final double pickupDistanceKm;
  final double tripDistanceKm;
  final double commissionPercent;
  final double targetThresholdPerKm;
  final String rawText;
  final DateTime timestamp;

  FareResult({
    required this.platform,
    required this.grossFare,
    required this.pickupDistanceKm,
    required this.tripDistanceKm,
    required this.commissionPercent,
    required this.targetThresholdPerKm,
    required this.rawText,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get totalDistanceKm => pickupDistanceKm + tripDistanceKm;

  double get platformDeduction => grossFare * (commissionPercent / 100.0);

  double get netFare => grossFare - platformDeduction;

  double get farePerKm {
    if (totalDistanceKm <= 0) return 0.0;
    return netFare / totalDistanceKm;
  }

  ProfitLevel get profitLevel {
    if (totalDistanceKm <= 0 || netFare <= 0) return ProfitLevel.unknown;
    if (farePerKm >= targetThresholdPerKm) {
      return ProfitLevel.high; // 🟢 Green
    } else if (farePerKm >= targetThresholdPerKm * 0.75) {
      return ProfitLevel.moderate; // 🟡 Yellow
    } else {
      return ProfitLevel.low; // 🔴 Red
    }
  }

  Color get statusColor {
    switch (profitLevel) {
      case ProfitLevel.high:
        return const Color(0xFF2E7D32); // Green
      case ProfitLevel.moderate:
        return const Color(0xFFF57F17); // Yellow/Orange
      case ProfitLevel.low:
        return const Color(0xFFC62828); // Red
      case ProfitLevel.unknown:
        return const Color(0xFF757575); // Grey
    }
  }

  String get formattedFarePerKm =>
      farePerKm > 0 ? "Rs. ${farePerKm.toStringAsFixed(1)}/km" : "N/A";

  String get formattedNetFare =>
      netFare > 0 ? "Rs. ${netFare.toStringAsFixed(0)}" : "N/A";

  String get formattedTotalDistance =>
      totalDistanceKm > 0 ? "${totalDistanceKm.toStringAsFixed(1)} km" : "N/A";

  Map<String, dynamic> toMap() {
    return {
      'platform': platform,
      'grossFare': grossFare,
      'pickupDistanceKm': pickupDistanceKm,
      'tripDistanceKm': tripDistanceKm,
      'commissionPercent': commissionPercent,
      'targetThresholdPerKm': targetThresholdPerKm,
      'rawText': rawText,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory FareResult.fromMap(Map<String, dynamic> map) {
    return FareResult(
      platform: map['platform'] ?? 'Unknown',
      grossFare: (map['grossFare'] as num?)?.toDouble() ?? 0.0,
      pickupDistanceKm: (map['pickupDistanceKm'] as num?)?.toDouble() ?? 0.0,
      tripDistanceKm: (map['tripDistanceKm'] as num?)?.toDouble() ?? 0.0,
      commissionPercent: (map['commissionPercent'] as num?)?.toDouble() ?? 0.0,
      targetThresholdPerKm: (map['targetThresholdPerKm'] as num?)?.toDouble() ?? 100.0,
      rawText: map['rawText'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
    );
  }
}
