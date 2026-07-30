import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_alert_window/system_alert_window.dart';
import 'core/models/fare_result.dart';

import 'core/parser/parser_engine.dart';
import 'core/services/background_service.dart';
import 'core/services/overlay_service.dart';
import 'core/services/storage_service.dart';
import 'features/disclosure/prominent_disclosure_screen.dart';
import 'features/permissions/permission_dashboard_screen.dart';
import 'features/settings/settings_screen.dart';
import 'providers/app_providers.dart';

@pragma('vm:entry-point')
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

// Entry point required by system_alert_window plugin for floating overlay rendering
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayWidget(),
    ),
  );
}



class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  String _title = "RideBuddy";
  String _body = "Monitoring fares...";
  bool _isProfitable = true;

  @override
  void initState() {
    super.initState();
    SystemAlertWindow.overlayListener.listen((data) {
      if (data is Map) {
        setState(() {
          _title = data['title']?.toString() ?? _title;
          _body = data['body']?.toString() ?? _body;
          _isProfitable = data['isProfitable'] as bool? ?? true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _isProfitable ? Colors.greenAccent : Colors.redAccent;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xEE1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isProfitable ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: statusColor,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _title,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _body,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
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

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initBackgroundService();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initBackgroundService();
    }
  }

  void _initBackgroundService() {
    final storage = ref.read(storageServiceProvider);
    final bgManager = ref.read(backgroundServiceManagerProvider);
    bgManager.startService(storage);
    bgManager.onFareCalculated = (_) {
      ref.read(fareHistoryProvider.notifier).refresh();
    };
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

class ServicePowerButton extends ConsumerStatefulWidget {
  const ServicePowerButton({super.key});

  @override
  ConsumerState<ServicePowerButton> createState() => _ServicePowerButtonState();
}

class _ServicePowerButtonState extends ConsumerState<ServicePowerButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgManager = ref.watch(backgroundServiceManagerProvider);
    final storage = ref.watch(storageServiceProvider);
    final isRunning = bgManager.isRunning;

    final color = isRunning ? const Color(0xFF00E676) : Colors.white38;
    final glowColor = isRunning ? const Color(0x6600E676) : Colors.transparent;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (isRunning) {
                bgManager.stopService();
                OverlayService.closeOverlay();
              } else {
                bgManager.startService(storage);
              }
              setState(() {});
            },
            child: ScaleTransition(
              scale: isRunning ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRunning ? const Color(0xFF1E2D24) : const Color(0xFF1E1E1E),
                  border: Border.all(
                    color: color,
                    width: 3.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor,
                      blurRadius: isRunning ? 24 : 0,
                      spreadRadius: isRunning ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: color,
                  size: 48,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              isRunning ? 'MONITORING ACTIVE' : 'MONITORING PAUSED',
              key: ValueKey(isRunning),
              style: TextStyle(
                color: isRunning ? const Color(0xFF00E676) : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isRunning
                ? 'Listening for Uber & PickMe fare offers...'
                : 'Tap power button to enable background monitoring',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
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
              const ServicePowerButton(),
              const SizedBox(height: 24),
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
      text: "Moto LKR210.61 ⚡ 16 mins (5.2 km) total 6 mins (1.9 km) away 9 mins (3.2 km) trip +LKR16.00 premium",
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Simulate Driver App Scenario', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Preset Scenarios:', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Uber LKR 210'),
                    backgroundColor: Colors.white10,
                    labelStyle: const TextStyle(color: Colors.amber, fontSize: 12),
                    onPressed: () {
                      textCtrl.text = "Moto LKR210.61 ⚡ 16 mins (5.2 km) total 6 mins (1.9 km) away 9 mins (3.2 km) trip +LKR16.00 premium";
                    },
                  ),
                  ActionChip(
                    label: const Text('PickMe 152 LKR'),
                    backgroundColor: Colors.white10,
                    labelStyle: const TextStyle(color: Colors.amber, fontSize: 12),
                    onPressed: () {
                      textCtrl.text = "152.15 LKR BIKE 💵 (2mins away, 0.6 km) (6 min, 2.08 km) Accept trip";
                    },
                  ),
                  ActionChip(
                    label: const Text('PickMe FLASH'),
                    backgroundColor: Colors.white10,
                    labelStyle: const TextStyle(color: Colors.amber, fontSize: 12),
                    onPressed: () {
                      textCtrl.text = "893.48 LKR FLASH Galle Road (2mins away, 0.4 km) (33 min, 13.32 km) 🔥 + LKR 75";
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Enter sample driver screen text...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
            child: const Text('TEST & OVERLAY'),
          ),
        ],
      ),
    );
  }
}
