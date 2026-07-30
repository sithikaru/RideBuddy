import 'package:flutter_test/flutter_test.dart';
import 'package:ridebuddy/core/models/driver_settings.dart';
import 'package:ridebuddy/core/models/fare_result.dart';
import 'package:ridebuddy/core/parser/parser_engine.dart';

void main() {
  group('ParserEngine Tests', () {
    const settings = DriverSettings(
      uberCommissionPercent: 10.0,
      pickmeCommissionPercent: 15.0,
      helagoCommissionPercent: 12.0,
      targetProfitPerKm: 100.0,
    );

    test('Parses Uber fare with LKR currency and km distance', () {
      const sampleText = 'Uber Trip Request: Pickup 1.5 km away. Dropoff 5.0 km. Fare: Rs. 850.00';
      final result = ParserEngine.parse(
        rawText: sampleText,
        packageName: 'com.ubercab.driver',
        settings: settings,
      );

      expect(result.platform, equals('Uber'));
      expect(result.grossFare, equals(850.0));
      expect(result.pickupDistanceKm, equals(1.5));
      expect(result.tripDistanceKm, equals(5.0));
      expect(result.totalDistanceKm, equals(6.5));
      expect(result.commissionPercent, equals(10.0));
      expect(result.platformDeduction, equals(85.0));
      expect(result.netFare, equals(765.0));
      expect(result.farePerKm, closeTo(117.69, 0.01));
      expect(result.profitLevel, equals(ProfitLevel.high));
    });

    test('Parses PickMe fare with meter pickup distance', () {
      const sampleText = 'PickMe Ride: 800 m pickup, 4.2 km trip. Total: LKR 400';
      final result = ParserEngine.parse(
        rawText: sampleText,
        packageName: 'com.pickme.driver',
        settings: settings,
      );

      expect(result.platform, equals('PickMe'));
      expect(result.grossFare, equals(400.0));
      expect(result.pickupDistanceKm, equals(0.8));
      expect(result.tripDistanceKm, equals(4.2));
      expect(result.totalDistanceKm, equals(5.0));
      expect(result.commissionPercent, equals(15.0));
      expect(result.platformDeduction, equals(60.0));
      expect(result.netFare, equals(340.0));
      expect(result.farePerKm, equals(68.0));
      expect(result.profitLevel, equals(ProfitLevel.low));
    });

    test('Handles missing variables gracefully', () {
      const sampleText = 'Ride request from passenger';
      final result = ParserEngine.parse(
        rawText: sampleText,
        packageName: 'com.ubercab.driver',
        settings: settings,
      );

      expect(result.grossFare, equals(0.0));
      expect(result.totalDistanceKm, equals(0.0));
      expect(result.formattedFarePerKm, equals('N/A'));
      expect(result.profitLevel, equals(ProfitLevel.unknown));
    });
  });
}
