import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/driver_settings.dart';
import '../core/models/fare_result.dart';
import '../core/services/background_service.dart';
import '../core/services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden in ProviderScope');
});

final backgroundServiceManagerProvider = Provider<BackgroundServiceManager>((ref) {
  return BackgroundServiceManager();
});

class SettingsNotifier extends Notifier<DriverSettings> {
  @override
  DriverSettings build() {
    final storage = ref.watch(storageServiceProvider);
    return storage.getSettings();
  }

  Future<void> updateSettings(DriverSettings newSettings) async {
    state = newSettings;
    final storage = ref.read(storageServiceProvider);
    await storage.saveSettings(newSettings);
  }

  Future<void> updateUberCommission(double val) async {
    await updateSettings(state.copyWith(uberCommissionPercent: val));
  }

  Future<void> updatePickmeCommission(double val) async {
    await updateSettings(state.copyWith(pickmeCommissionPercent: val));
  }

  Future<void> updateHelagoCommission(double val) async {
    await updateSettings(state.copyWith(helagoCommissionPercent: val));
  }

  Future<void> updateTargetProfit(double val) async {
    await updateSettings(state.copyWith(targetProfitPerKm: val));
  }

  Future<void> toggleAutoOverlay(bool val) async {
    await updateSettings(state.copyWith(autoShowOverlay: val));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, DriverSettings>(SettingsNotifier.new);

class DisclosureNotifier extends Notifier<bool> {
  @override
  bool build() {
    final storage = ref.watch(storageServiceProvider);
    return storage.hasAcceptedDisclosure();
  }

  Future<void> acceptDisclosure() async {
    final storage = ref.read(storageServiceProvider);
    await storage.setDisclosureAccepted(true);
    state = true;
  }
}

final disclosureAcceptedProvider = NotifierProvider<DisclosureNotifier, bool>(DisclosureNotifier.new);

class FareHistoryNotifier extends Notifier<List<FareResult>> {
  @override
  List<FareResult> build() {
    final storage = ref.watch(storageServiceProvider);
    return storage.getFareHistory();
  }

  void refresh() {
    final storage = ref.read(storageServiceProvider);
    state = storage.getFareHistory();
  }

  Future<void> clear() async {
    final storage = ref.read(storageServiceProvider);
    await storage.clearHistory();
    state = [];
  }
}

final fareHistoryProvider = NotifierProvider<FareHistoryNotifier, List<FareResult>>(FareHistoryNotifier.new);

