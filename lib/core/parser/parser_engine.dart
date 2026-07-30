import '../models/driver_settings.dart';
import '../models/fare_result.dart';

class ParserEngine {
  /// Extract fare, pickup distance, trip distance, vehicle category, and surge bonus
  /// from raw screen text or notifications for Uber & PickMe (In-app, Pop-up Overlay, Flash/Parcel).
  static FareResult parse({
    required String rawText,
    required String packageName,
    required DriverSettings settings,
  }) {
    final platform = _detectPlatform(packageName, rawText);
    final commissionPercent = _getCommissionForPlatform(platform, settings);

    final grossFare = _extractGrossFare(rawText);
    final distanceData = _extractDistances(rawText);

    final pickupDistance = distanceData['pickup'] ?? 0.0;
    final tripDistance = distanceData['trip'] ?? 0.0;

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

    // 1. Package Name Identification
    if (lowerPkg.contains('ubercab') || lowerPkg.contains('uber')) {
      return 'Uber';
    }
    if (lowerPkg.contains('pickme')) {
      return 'PickMe';
    }
    if (lowerPkg.contains('helago')) {
      return 'Helago';
    }

    // 2. Layout Signature Identification (for pop-up banners over home screen or other apps)
    if (lowerText.contains('accept trip') ||
        lowerText.contains('trip scanner') ||
        lowerText.contains('flash') ||
        RegExp(r'[0-9.]+\s*lkr').hasMatch(lowerText)) {
      return 'PickMe';
    }

    if (lowerText.contains('match') ||
        lowerText.contains('total') ||
        RegExp(r'lkr\s*[0-9.]').hasMatch(lowerText)) {
      return 'Uber';
    }

    if (lowerText.contains('helago')) {
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

  /// Extract gross fare with support for:
  /// - LKR210.61, LKR150, LKR 150.00
  /// - 152.15 LKR, 893.48 LKR (PickMe format where LKR is suffix)
  /// - Rs. 850.00, රු. 500, ரூ. 500
  static double _extractGrossFare(String text) {
    final List<double> candidates = [];

    // 1. Check LKR prefix (e.g. LKR210.61, LKR 150)
    final prefixExp = RegExp(
      r'(?:LKR|Rs\.?|රු\.?|ரூ\.?)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    for (final match in prefixExp.allMatches(text)) {
      final rawNum = match.group(1)?.replaceAll(',', '');
      if (rawNum != null) {
        final val = double.tryParse(rawNum);
        if (val != null && val > 0 && val <= 50000.0) {
          candidates.add(val);
        }
      }
    }

    // 2. Check LKR suffix (e.g. 152.15 LKR, 893.48 LKR - PickMe format)
    final suffixExp = RegExp(
      r'([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\s*(?:LKR|Rs\.?|රු\.?|ரூ\.?)',
      caseSensitive: false,
    );
    for (final match in suffixExp.allMatches(text)) {
      final rawNum = match.group(1)?.replaceAll(',', '');
      if (rawNum != null) {
        final val = double.tryParse(rawNum);
        if (val != null && val > 0 && val <= 50000.0) {
          candidates.add(val);
        }
      }
    }

    if (candidates.isEmpty) return 0.0;

    // Return the primary fare (maximum value amongst parsed currency candidates <= 50,000)
    candidates.sort((a, b) => b.compareTo(a));
    return candidates.first;
  }

  /// Extract pickup and trip distances in kilometers
  /// Handles:
  /// - Uber format: "6 mins (1.9 km) away", "9 mins (3.2 km) trip", "16 mins (5.2 km) total"
  /// - PickMe format: "(2mins away, 0.6 km)", "(6 min, 2.08 km)", "(33 min, 13.32 km)"
  static Map<String, double> _extractDistances(String text) {
    double pickup = 0.0;
    double trip = 0.0;

    // A. Uber Total Distance line: e.g. "16 mins (5.2 km) total"
    final totalExp = RegExp(r'\(([0-9]+(?:\.[0-9]+)?)\s*km\)\s*total', caseSensitive: false);
    final totalMatch = totalExp.firstMatch(text);
    double? totalFromText;
    if (totalMatch != null) {
      final val = double.tryParse(totalMatch.group(1) ?? '');
      if (val != null && val > 0 && val <= 200.0) {
        totalFromText = val;
      }
    }

    // B. Pickup Distance: e.g. "6 mins (1.9 km) away" or "2mins away, 0.6 km" or "(0.5 km) away"
    final pickupExp1 = RegExp(r'\(([0-9]+(?:\.[0-9]+)?)\s*km\)\s*away', caseSensitive: false);
    final pickupExp2 = RegExp(r'away,\s*([0-9]+(?:\.[0-9]+)?)\s*km', caseSensitive: false);
    final pickupExp3 = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*km\s*pickup', caseSensitive: false);

    var matchP = pickupExp1.firstMatch(text) ?? pickupExp2.firstMatch(text) ?? pickupExp3.firstMatch(text);
    if (matchP != null) {
      final pVal = double.tryParse(matchP.group(1) ?? '');
      if (pVal != null && pVal > 0 && pVal <= 150.0) {
        pickup = pVal;
      }
    }

    // C. Trip Distance: e.g. "9 mins (3.2 km) trip" or "(6 min, 2.08 km)" or "(33 min, 13.32 km)"
    final tripExp1 = RegExp(r'\(([0-9]+(?:\.[0-9]+)?)\s*km\)\s*trip', caseSensitive: false);
    final tripExp2 = RegExp(r'\([0-9]+\s*min[s]?,\s*([0-9]+(?:\.[0-9]+)?)\s*km\)', caseSensitive: false);

    var matchT = tripExp1.firstMatch(text) ?? tripExp2.firstMatch(text);
    if (matchT != null) {
      final tVal = double.tryParse(matchT.group(1) ?? '');
      if (tVal != null && tVal > 0 && tVal <= 200.0) {
        trip = tVal;
      }
    }

    // D. Fallback if specific patterns didn't match: parse explicit (X.X km) or (X.X m) occurrences
    if (pickup == 0.0 && trip == 0.0) {
      final allKmExp = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(km|kms|meter|meters)\b', caseSensitive: false);
      final matches = allKmExp.allMatches(text).toList();
      final List<double> extracted = [];
      for (final m in matches) {
        final val = double.tryParse(m.group(1) ?? '');
        final unit = m.group(2)?.toLowerCase();
        if (val != null && val > 0 && val <= 200.0) {
          final inKm = (unit == 'meter' || unit == 'meters') ? val / 1000.0 : val;
          if (inKm >= 0.1 && inKm <= 200.0) {
            extracted.add(inKm);
          }
        }
      }

      if (extracted.length >= 2) {
        pickup = extracted[0];
        trip = extracted[1];
      } else if (extracted.length == 1) {
        if (totalFromText != null && totalFromText > extracted[0]) {
          pickup = extracted[0];
          trip = totalFromText - pickup;
        } else {
          trip = extracted[0];
        }
      }
    }

    // Bounds check
    if (pickup > 150.0) pickup = 0.0;
    if (trip > 200.0) trip = 0.0;

    return {
      'pickup': pickup,
      'trip': trip,
    };
  }
}
