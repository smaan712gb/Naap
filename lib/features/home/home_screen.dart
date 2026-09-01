import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../capture/capture_screen.dart';
import '../profile/profile_screen.dart';
import '../results/results_screen.dart';
import '../shop/shop_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profileDone = state.profile.name.isNotEmpty;
    final measured = state.hasMeasurements;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Naap', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Text('ناپ', style: TextStyle(fontSize: 18)),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: const Color(0xFFE8F1EC),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: Color(0xFF1B4D3E)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Everything happens on your phone. Your photos are analyzed on-device, then deleted. Only numbers go on the parchi.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _StepTile(
            index: 1,
            title: 'Your details',
            subtitle: profileDone
                ? '${state.profile.name} · ${state.profile.heightCm.toStringAsFixed(0)} cm'
                : 'Name, height, weight — height calibrates the camera',
            done: profileDone,
            enabled: true,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          _StepTile(
            index: 2,
            title: 'Guided capture',
            subtitle: measured
                ? 'Measured — retake anytime'
                : 'Two photos: front and side. Takes 2 minutes.',
            done: measured,
            enabled: profileDone,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CaptureScreen())),
          ),
          _StepTile(
            index: 3,
            title: 'Review & send parchi',
            subtitle: measured
                ? 'Check your naap, pick a garment, WhatsApp your tailor'
                : 'Available after capture',
            done: false,
            enabled: measured,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ResultsScreen())),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFFC9A227),
                  child: Icon(Icons.storefront, color: Colors.white)),
              title: const Text('Fabric Shop',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Beta — unstitched fabrics, stitched to your naap'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ShopScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final bool done;
  final bool enabled;
  final VoidCallback onTap;

  const _StepTile({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        enabled: enabled,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor:
              done ? const Color(0xFF1B4D3E) : Colors.grey.shade300,
          child: done
              ? const Icon(Icons.check, color: Colors.white)
              : Text('$index',
                  style: TextStyle(
                      color: enabled ? Colors.black87 : Colors.grey)),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
