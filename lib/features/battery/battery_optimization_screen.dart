import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BatteryOptimizationScreen extends StatelessWidget {
  const BatteryOptimizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Battery Optimization Guide', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.battery_alert_outlined, color: Colors.amber, size: 30),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Android aggressively terminates background apps. Exclude RideBuddy from battery saver restrictions to ensure uninterrupted profit alerts.',
                      style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.settings),
                label: const Text(
                  'OPEN BATTERY SETTINGS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await Permission.ignoreBatteryOptimizations.request();
                },
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Manufacturer-Specific Guides',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 14),
            _buildOemTile(
              brand: 'Samsung',
              steps: [
                '1. Open Settings -> Battery and Device Care -> Battery',
                '2. Tap "Background usage limits"',
                '3. Add RideBuddy to "Never sleeping apps"',
              ],
            ),
            const SizedBox(height: 12),
            _buildOemTile(
              brand: 'Xiaomi / Poco / MIUI',
              steps: [
                '1. Open Settings -> Apps -> Manage Apps -> RideBuddy',
                '2. Enable "Autostart"',
                '3. Set Battery Saver to "No restrictions"',
              ],
            ),
            const SizedBox(height: 12),
            _buildOemTile(
              brand: 'Oppo / Realme',
              steps: [
                '1. Open Settings -> Battery -> App Battery Management',
                '2. Select RideBuddy',
                '3. Enable "Allow background activity" & "Allow autostart"',
              ],
            ),
            const SizedBox(height: 12),
            _buildOemTile(
              brand: 'Vivo',
              steps: [
                '1. Open Settings -> Battery -> High background power consumption',
                '2. Enable toggle for RideBuddy',
              ],
            ),
            const SizedBox(height: 12),
            _buildOemTile(
              brand: 'OnePlus',
              steps: [
                '1. Open Settings -> Battery -> Battery Optimization',
                '2. Find RideBuddy and select "Don\'t optimize"',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOemTile({
    required String brand,
    required List<String> steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Text(
                brand,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                step,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
