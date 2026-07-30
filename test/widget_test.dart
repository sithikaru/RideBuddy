import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ridebuddy/core/services/storage_service.dart';
import 'package:ridebuddy/main.dart';
import 'package:ridebuddy/providers/app_providers.dart';

void main() {
  testWidgets('Prominent Disclosure screen renders initially when not accepted', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = StorageService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
        ],
        child: const RideBuddyApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Data & Privacy Disclosure'), findsOneWidget);
    expect(find.text('ACCEPT & CONTINUE'), findsOneWidget);
  });
}
