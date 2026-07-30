import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/models/fare_result.dart';

import 'core/parser/parser_engine.dart';
import 'core/services/background_service.dart';
import 'core/services/overlay_service.dart';
import 'core/services/storage_service.dart';
import 'features/disclosure/prominent_disclosure_screen.dart';
import 'features/permissions/permission_dashboard_screen.dart';
import 'features/settings/settings_screen.dart';
import 'providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await StorageService.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const RideBuddyApp(),
    ),
  );
}

class RideBuddyApp extends ConsumerWidget {
  const RideBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAcceptedDisclosure = ref.watch(disclosureAcceptedProvider);

    return MaterialApp(
      title: 'RideBuddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: hasAcceptedDisclosure
          ? const MainNavigationScreen()
          : ProminentDisclosureScreen(
              onAccepted: () {
                // Navigation state handled automatically by disclosureAcceptedProvider
              },
            ),
    );
  }
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Start background listeners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(storageServiceProvider);
      final bgManager = ref.read(backgroundServiceManagerProvider);
      bgManager.startService(storage);
      bgManager.onFareCalculated = (_) {
        ref.read(fareHistoryProvider.notifier).refresh();
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardTab(),
      const PermissionDashboardScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.white54,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.speed_outlined),
            activeIcon: Icon(Icons.speed),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield_outlined),
            activeIcon: Icon(Icons.shield),
            label: 'Permissions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune_outlined),
            activeIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(fareHistoryProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            const Icon(Icons.navigation_outlined, color: Colors.amber),
            const SizedBox(width: 10),
            const Text('RideBuddy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined, color: Colors.amber),
            tooltip: 'Simulate Ride Request',
            onPressed: () => _showSimulationDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(fareHistoryProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTargetSummaryCard(settings),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Fare Calculations',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (history.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(fareHistoryProvider.notifier).clear();
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (history.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.access_time, color: Colors.white38, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'No fare requests captured yet',
                        style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Open your driver app or tap the bug icon top right to simulate a request.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final fare = history[idx];
                    return _buildFareCard(context, fare);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetSummaryCard(settings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Target Profit Goal',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Rs. ${settings.targetProfitPerKm.toStringAsFixed(0)} / km',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Uber ${settings.uberCommissionPercent}% | PM ${settings.pickmeCommissionPercent}%',
                  style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareCard(BuildContext context, FareResult fare) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fare.statusColor.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: fare.statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    fare.platform,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: fare.statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fare.formattedFarePerKm,
                  style: TextStyle(
                    color: fare.statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem('Gross Fare', "Rs. ${fare.grossFare.toStringAsFixed(0)}"),
              _buildDetailItem('Net Fare', fare.formattedNetFare),
              _buildDetailItem('Total Dist.', fare.formattedTotalDistance),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  void _showSimulationDialog(BuildContext context, WidgetRef ref) {
    final textCtrl = TextEditingController(
      text: "Uber Trip Request: Pickup 1.5 km away. Dropoff 5.0 km. Fare: Rs. 850.00",
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Simulate Ride Request Text', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textCtrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter sample driver screen text...',
            hintStyle: TextStyle(color: Colors.white38),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              final settings = ref.read(settingsProvider);
              final storage = ref.read(storageServiceProvider);

              final result = ParserEngine.parse(
                rawText: textCtrl.text,
                packageName: 'com.ubercab.driver',
                settings: settings,
              );

              await storage.saveFareResult(result);
              ref.read(fareHistoryProvider.notifier).refresh();
              await OverlayService.showProfitOverlay(result);
            },
            child: const Text('PARSER TEST & OVERLAY'),
          ),
        ],
      ),
    );
  }
}
