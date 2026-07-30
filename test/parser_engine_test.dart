import 'package:flutter_test/flutter_test.dart';
import 'package:ridebuddy/core/models/driver_settings.dart';
import 'package:ridebuddy/core/models/fare_result.dart';
import 'package:ridebuddy/core/parser/parser_engine.dart';

void main() {
  group('ParserEngine Sri Lanka Live Screenshot Tests', () {
    const settings = DriverSettings(
      uberCommissionPercent: 10.0,
      pickmeCommissionPercent: 15.0,
      helagoCommissionPercent: 12.0,
      targetProfitPerKm: 100.0,
    );

    test('Live Uber Screenshot: LKR205.52 Moto Request', () {
      const sampleText = '''
        Moto LKR205.52 ⭐ 4.91
        17 mins (4.9 km) total
        5 mins (1.4 km) away Graphix For U, WP
        12 mins (3.5 km) trip LEGION FITNESS LK, WP
        +LKR16.00 premium Match
      ''';

      final result = ParserEngine.parse(
        rawText: sampleText,
        packageName: 'com.ubercab', // Package name on device can be com.ubercab
        settings: settings,
      );

      expect(result.platform, equals('Uber'));
      expect(result.grossFare, equals(205.52));
      expect(result.pickupDistanceKm, equals(1.4));
      expect(result.tripDistanceKm, equals(3.5));
      expect(result.totalDistanceKm, equals(4.9));
      expect(result.commissionPercent, equals(10.0));
      expect(result.platformDeduction, closeTo(20.55, 0.01));
      expect(result.netFare, closeTo(184.97, 0.01));
      expect(result.farePerKm, closeTo(37.74, 0.05));
    });
  });
}
