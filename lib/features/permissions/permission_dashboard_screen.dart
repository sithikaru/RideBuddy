import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/background_service.dart';
import '../../core/services/overlay_service.dart';
import '../battery/battery_optimization_screen.dart';

class PermissionDashboardScreen extends StatefulWidget {
  const PermissionDashboardScreen({super.key});

  @override
  State<PermissionDashboardScreen> createState() => _PermissionDashboardScreenState();
}

class _PermissionDashboardScreenState extends State<PermissionDashboardScreen>
    with WidgetsBindingObserver {
  bool _accessibilityGranted = false;
  bool _notificationGranted = false;
  bool _overlayGranted = false;
  bool _batteryOptimizationExempt = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);

    final accessibility = await BackgroundServiceManager.isAccessibilityGranted();
    final notification = await BackgroundServiceManager.isNotificationListenerGranted();
    final overlay = await OverlayService.checkPermission();
    final batteryExempt = await Permission.ignoreBatteryOptimizations.isGranted;

    if (mounted) {
      setState(() {
        _accessibilityGranted = accessibility;
        _notificationGranted = notification;
        _overlayGranted = overlay;
        _batteryOptimizationExempt = batteryExempt;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Permission Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _checkPermissions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusOverviewHeader(),
                  const SizedBox(height: 24),
                  const Text(
                    'Required System Services',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPermissionTile(
                    title: 'Accessibility Service',
                    subtitle: 'Reads ride request screen view hierarchy from Uber, PickMe, Helago.',
                    isGranted: _accessibilityGranted,
                    onTap: () async {
                      await BackgroundServiceManager.requestAccessibilityPermission();
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildPermissionTile(
                    title: 'System Overlay Window',
                    subtitle: 'Draws floating net profit per km pill over ride-hailing apps.',
                    isGranted: _overlayGranted,
                    onTap: () async {
                      await OverlayService.requestPermission();
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildPermissionTile(
                    title: 'Notification Listener (Fallback)',
                    subtitle: 'Extracts fare rates from push notifications if screen text is hidden.',
                    isGranted: _notificationGranted,
                    onTap: () async {
                      await BackgroundServiceManager.requestNotificationListenerPermission();
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildPermissionTile(
                    title: 'Disable Battery Optimization',
                    subtitle: 'Prevents Android from killing RideBuddy background calculation service.',
                    isGranted: _batteryOptimizationExempt,
                    onTap: () async {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BatteryOptimizationScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusOverviewHeader() {
    final allGranted = _accessibilityGranted && _overlayGranted && _notificationGranted;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: allGranted
            ? const Color(0xFF1B5E20).withOpacity(0.4)
            : const Color(0xFFE65100).withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allGranted ? Colors.green : Colors.orange,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            allGranted ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: allGranted ? Colors.greenAccent : Colors.orangeAccent,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allGranted ? 'RideBuddy Active' : 'Setup Action Required',
                  style: TextStyle(
                    color: allGranted ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allGranted
                      ? 'All core services are enabled. Profit alerts will show on incoming requests.'
                      : 'Please grant the required system permissions below to enable background fare calculations.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.3),
          ),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isGranted ? Colors.green.withOpacity(0.2) : Colors.amber,
            foregroundColor: isGranted ? Colors.greenAccent : Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: onTap,
          child: Text(
            isGranted ? 'ACTIVE' : 'ENABLE',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
