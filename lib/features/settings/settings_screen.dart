import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _uberCtrl;
  late TextEditingController _pickmeCtrl;
  late TextEditingController _helagoCtrl;
  late TextEditingController _targetCtrl;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _uberCtrl = TextEditingController(text: settings.uberCommissionPercent.toStringAsFixed(1));
    _pickmeCtrl = TextEditingController(text: settings.pickmeCommissionPercent.toStringAsFixed(1));
    _helagoCtrl = TextEditingController(text: settings.helagoCommissionPercent.toStringAsFixed(1));
    _targetCtrl = TextEditingController(text: settings.targetProfitPerKm.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _uberCtrl.dispose();
    _pickmeCtrl.dispose();
    _helagoCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  void _saveAll() {
    final uber = double.tryParse(_uberCtrl.text) ?? 10.0;
    final pickme = double.tryParse(_pickmeCtrl.text) ?? 15.0;
    final helago = double.tryParse(_helagoCtrl.text) ?? 12.0;
    final target = double.tryParse(_targetCtrl.text) ?? 100.0;

    final current = ref.read(settingsProvider);
    ref.read(settingsProvider.notifier).updateSettings(
          current.copyWith(
            uberCommissionPercent: uber,
            pickmeCommissionPercent: pickme,
            helagoCommissionPercent: helago,
            targetProfitPerKm: target,
          ),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Platform & Goal Settings', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.amber),
            onPressed: _saveAll,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Target Profit Goal',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            _buildInputField(
              controller: _targetCtrl,
              label: 'Target Minimum Earnings per KM (LKR)',
              hint: 'e.g. 100',
              prefixText: 'Rs. ',
              icon: Icons.flag_outlined,
            ),
            const SizedBox(height: 24),
            const Text(
              'Platform Commission Rates (%)',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            _buildInputField(
              controller: _uberCtrl,
              label: 'Uber Driver Commission %',
              hint: 'e.g. 10.0',
              suffixText: '%',
              icon: Icons.directions_car_outlined,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _pickmeCtrl,
              label: 'PickMe Driver Commission %',
              hint: 'e.g. 15.0',
              suffixText: '%',
              icon: Icons.local_taxi_outlined,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _helagoCtrl,
              label: 'Helago Driver Commission %',
              hint: 'e.g. 12.0',
              suffixText: '%',
              icon: Icons.electric_rickshaw_outlined,
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: SwitchListTile(
                value: settings.autoShowOverlay,
                activeColor: Colors.amber,
                title: const Text(
                  'Auto-Show Floating Profit Overlay',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: const Text(
                  'Displays instant profit per km bubble on incoming request screen',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                onChanged: (val) {
                  ref.read(settingsProvider.notifier).toggleAutoOverlay(val);
                },
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _saveAll,
                child: const Text(
                  'SAVE SETTINGS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? prefixText,
    String? suffixText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.amber),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30),
          prefixText: prefixText,
          prefixStyle: const TextStyle(color: Colors.white70),
          suffixText: suffixText,
          suffixStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
