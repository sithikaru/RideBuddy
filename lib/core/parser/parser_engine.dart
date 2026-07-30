import '../models/driver_settings.dart';
import '../models/fare_result.dart';

class ParserEngine {
  /// Extract fare, pickup distance, and trip distance from raw text node or notification string.
  static FareResult parse({
    required String rawText,
    required String packageName,
    required DriverSettings settings,
  }) {
    final platform = _detectPlatform(packageName, rawText);
    final commissionPercent = _getCommissionForPlatform(platform, settings);

    final fares = _extractFares(rawText);
    final distances = _extractDistancesInKm(rawText);

    double grossFare = fares.isNotEmpty ? fares.first : 0.0;

    double pickupDistance = 0.0;
    double tripDistance = 0.0;

    if (distances.length >= 2) {
      pickupDistance = distances[0];
      tripDistance = distances[1];
    } else if (distances.length == 1) {
      tripDistance = distances[0];
    }

    return FareResult(
      platform: platform,
      grossFare: grossFare,
      pickupDistanceKm: pickupDistance,
      tripDistanceKm: tripDistance,
      commissionPercent: commissionPercent,
      targetThresholdPerKm: settings.targetProfitPerKm,
      rawText: rawText,
    );
  }

  static String _detectPlatform(String packageName, String text) {
    final lowerPkg = packageName.toLowerCase();
    final lowerText = text.toLowerCase();

    if (lowerPkg.contains('uber') || lowerText.contains('uber')) {
      return 'Uber';
    } else if (lowerPkg.contains('pickme') || lowerText.contains('pickme')) {
      return 'PickMe';
    } else if (lowerPkg.contains('helago') || lowerText.contains('helago')) {
      return 'Helago';
    }
    return 'Driver App';
  }

  static double _getCommissionForPlatform(String platform, DriverSettings settings) {
    switch (platform) {
      case 'Uber':
        return settings.uberCommissionPercent;
      case 'PickMe':
        return settings.pickmeCommissionPercent;
      case 'Helago':
        return settings.helagoCommissionPercent;
      default:
        return 12.0;
    }
  }

  /// Extract currency values formatted like LKR 500, Rs. 1,200.00, Rs 450
  static List<double> _extractFares(String text) {
    final List<double> results = [];
    final regExp = RegExp(
      r'(?:LKR|Rs\.?)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    final matches = regExp.allMatches(text);
    for (final match in matches) {
      final rawNum = match.group(1)?.replaceAll(',', '');
      if (rawNum != null) {
        final val = double.tryParse(rawNum);
        if (val != null && val > 0) {
          results.add(val);
        }
      }
    }

    // Fallback: If no currency prefix found, search for numbers followed by LKR or Rs
    if (results.isEmpty) {
      final fallbackExp = RegExp(
        r'([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\s*(?:LKR|Rs\.?)',
        caseSensitive: false,
      );
      final fallbackMatches = fallbackExp.allMatches(text);
      for (final match in fallbackMatches) {
        final rawNum = match.group(1)?.replaceAll(',', '');
        if (rawNum != null) {
          final val = double.tryParse(rawNum);
          if (val != null && val > 0) {
            results.add(val);
          }
        }
      }
    }

    return results;
  }

  /// Extract distances in kilometers. Handles "km" and "m" (meters converted to km).
  static List<double> _extractDistancesInKm(String text) {
    final List<double> results = [];
    final regExp = RegExp(
      r'([0-9]+(?:\.[0-9]+)?)\s*(km|m)\b',
      caseSensitive: false,
    );

    final matches = regExp.allMatches(text);
    for (final match in matches) {
      final valueStr = match.group(1);
      final unit = match.group(2)?.toLowerCase();
      if (valueStr != null && unit != null) {
        final val = double.tryParse(valueStr);
        if (val != null && val > 0) {
          if (unit == 'km') {
            results.add(val);
          } else if (unit == 'm') {
            results.add(val / 1000.0);
          }
        }
      }
    }
    return results;
  }
}
