import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

class ProminentDisclosureScreen extends ConsumerWidget {
  final VoidCallback onAccepted;

  const ProminentDisclosureScreen({super.key, required this.onAccepted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.amber,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data & Privacy Disclosure',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Google Play Compliance',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildDisclosureCard(
                        icon: Icons.screen_search_desktop_outlined,
                        iconColor: Colors.lightBlueAccent,
                        title: 'What Information We Access',
                        description:
                            'RideBuddy reads screen view text nodes and incoming push notifications strictly from driver apps (Uber Driver, PickMe Driver, Helago Driver) when a ride request is displayed.',
                      ),
                      const SizedBox(height: 16),
                      _buildDisclosureCard(
                        icon: Icons.calculate_outlined,
                        iconColor: Colors.greenAccent,
                        title: 'Why We Need This Access',
                        description:
                            'This data is required to calculate your gross fare, platform commission, pickup distance, and net earnings per kilometer, presenting a floating profit indicator over your driver app.',
                      ),
                      const SizedBox(height: 16),
                      _buildDisclosureCard(
                        icon: Icons.lock_outline,
                        iconColor: Colors.purpleAccent,
                        title: '100% Local & Confidential',
                        description:
                            'Your trip details stay strictly on your device. No data is ever transmitted, uploaded to servers, auto-accepted, or shared with third parties.',
                      ),
                      const SizedBox(height: 16),
                      _buildDisclosureCard(
                        icon: Icons.touch_app_outlined,
                        iconColor: Colors.orangeAccent,
                        title: 'No Autonomous Actions',
                        description:
                            'RideBuddy is exclusively a calculation & visual assistance tool. It will NEVER auto-click, auto-accept, or auto-reject rides for you.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    await ref.read(disclosureAcceptedProvider.notifier).acceptDisclosure();
                    onAccepted();
                  },
                  child: const Text(
                    'ACCEPT & CONTINUE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisclosureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
