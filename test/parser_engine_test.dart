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
      targetProfitPerKm: 60.0,
    );

    test('Live Uber Screenshot 5: LKR270.40 Request', () {
      const sampleText = '''
        Moto LKR270.40 Cash payment ⭐ 4.85
        21 mins (6.4 km) total
        4 mins (0.9 km) away 20a Sri Dharmapala Mawatha
        17 mins (5.5 km) trip Old Kesbewa Rd
        +LKR12.00 premium Accept
      ''';

      final result = ParserEngine.parse(
        rawText: sampleText,
        packageName: 'com.ubercab',
        settings: settings,
      );

      expect(result.platform, equals('Uber'));
      expect(result.grossFare, equals(270.40));
      expect(result.pickupDistanceKm, equals(0.9));
      expect(result.tripDistanceKm, equals(5.5));
      expect(result.totalDistanceKm, closeTo(6.4, 0.01));
      expect(result.netFare, closeTo(243.36, 0.01));
      expect(result.farePerKm, closeTo(38.025, 0.05));
    });
  });
}
