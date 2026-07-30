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

    test('Live Uber Screenshot 1: LKR205.52 Request', () {
      const sampleText = '''
        Moto LKR205.52 ⭐ 4.91
        17 mins (4.9 km) total
        5 mins (1.4 km) away Graphix For U, WP
        12 mins (3.5 km) trip LEGION FITNESS LK, WP
        +LKR16.00 premium Match
      ''';

      final result = ParserEngine.parse(
        rawText: sampleText,
        packageName: 'com.ubercab',
        settings: settings,
      );

      expect(result.platform, equals('Uber'));
      expect(result.grossFare, equals(205.52));
      expect(result.pickupDistanceKm, equals(1.4));
      expect(result.tripDistanceKm, equals(3.5));
      expect(result.totalDistanceKm, equals(4.9));
    });

    test('Live Uber Screenshot 2: LKR350.74 Request', () {
      const sampleText = '''
        Moto LKR350.74 ⭐ 4.93
        23 mins (8.7 km) total
        6 mins (1.8 km) away 59, 7 Peter's Ln
        17 mins (6.9 km) trip Spa Ceylon - Kollupitiya - Spa & Boutique, WP
        +LKR18.00 premium Match
      ''';

      final result = ParserEngine.parse(
        rawText: sampleText,
        packageName: 'com.ubercab',
        settings: settings,
      );

      expect(result.platform, equals('Uber'));
      expect(result.grossFare, equals(350.74));
      expect(result.pickupDistanceKm, equals(1.8));
      expect(result.tripDistanceKm, equals(6.9));
      expect(result.totalDistanceKm, closeTo(8.7, 0.01));
      expect(result.netFare, closeTo(315.666, 0.01));
      expect(result.farePerKm, closeTo(36.28, 0.05));
    });

    test('Live Uber Screenshot 3: LKR150 Cash Payment Request', () {
      const sampleText = '''
        Moto LKR150 Cash payment ⭐ 4.85
        10 mins (3.1 km) total
        4 mins (1.1 km) away 32 Sudarma Mawatha
        6 mins (1.9 km) trip Amana Takaful Insurance, WP 10350
        +LKR10.00 premium Match
      ''';

      final result = ParserEngine.parse(
        rawText: sampleText,
        packageName: 'com.ubercab',
        settings: settings,
      );

      expect(result.platform, equals('Uber'));
      expect(result.grossFare, equals(150.0));
      expect(result.pickupDistanceKm, equals(1.1));
      expect(result.tripDistanceKm, equals(1.9));
      expect(result.totalDistanceKm, equals(3.0));
      expect(result.netFare, equals(135.0));
      expect(result.farePerKm, equals(45.0));
    });
  });
}
