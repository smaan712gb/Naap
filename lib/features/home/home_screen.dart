import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/app_version.dart';
import '../capture/capture_screen.dart';
import '../profile/profile_screen.dart';
import '../results/results_screen.dart';
import '../shop/shop_screen.dart';

/// Sideloaded Android has no store auto-update: check the published build
/// stamp and offer the download when a newer one exists. iOS updates flow
/// through TestFlight automatically, so the card is Android-only.
Future<bool> _updateAvailable() async {
  if (!Platform.isAndroid) return false;
  try {
    final resp = await http
        .get(Uri.parse(kVersionUrl))
        .timeout(const Duration(seconds: 6));
    if (resp.statusCode != 200) return false;
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    return (j['build'] as num? ?? 0) > kNaapBuild;
  } catch (_) {
    return false; // offline = no nagging
  }
}

void _showClients(BuildContext context, AppState state) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text('Who is being measured? — کس کا ناپ؟',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        for (final c in state.clients)
          ListTile(
            leading: Icon(c.id == state.active.id
                ? Icons.radio_button_checked
                : Icons.radio_button_off),
            title: Text(
                c.profile.name.isEmpty ? '(no name yet)' : c.profile.name),
            subtitle: Text(c.naap.values.isEmpty
                ? 'not measured yet'
                : 'measured · ${c.profile.heightCm.toStringAsFixed(0)} cm'),
            trailing: state.clients.length > 1
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      await state.deleteClient(c.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    })
                : null,
            onTap: () async {
              await state.switchClient(c.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ListTile(
          leading: const Icon(Icons.storefront_outlined),
          title: Text(state.shopName.isEmpty
              ? 'Tailor? Add your shop name — دکان کا نام'
              : 'Shop: ${state.shopName}'),
          subtitle: const Text('Printed on every parchi you make'),
          onTap: () async {
            Navigator.pop(ctx);
            final ctrl = TextEditingController(text: state.shopName);
            final name = await showDialog<String>(
              context: context,
              builder: (dctx) => AlertDialog(
                title: const Text('Your shop name'),
                content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                        hintText: 'e.g. Khan Tailors, Lahore')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dctx),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dctx, ctrl.text),
                      child: const Text('Save')),
                ],
              ),
            );
            if (name != null) await state.setShopName(name);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.translate),
          title: const Text('Bilingual parchi (EN + اردو)'),
          subtitle: const Text('Off = English-only, for Western tailors'),
          value: state.parchiBilingual,
          onChanged: (v) => state.setParchiBilingual(v),
        ),
        ListTile(
          leading: const Icon(Icons.person_add_alt),
          title: const Text('Add person — نیا گاہک'),
          onTap: () async {
            Navigator.pop(ctx);
            final ctrl = TextEditingController();
            final name = await showDialog<String>(
              context: context,
              builder: (dctx) => AlertDialog(
                title: const Text('New person'),
                content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration:
                        const InputDecoration(hintText: 'Name / نام')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dctx),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dctx, ctrl.text.trim()),
                      child: const Text('Add')),
                ],
              ),
            );
            if (name != null && name.isNotEmpty) {
              await state.newClient(name);
            }
          },
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

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
        actions: [
          // Phase 2 assisted mode: one phone, many measured people — a
          // family, or a tailor's whole client book.
          IconButton(
            tooltip: 'Clients / گاہک',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () => _showClients(context, state),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FutureBuilder<bool>(
            future: _updateAvailable(),
            builder: (context, snap) => snap.data == true
                ? Card(
                    color: const Color(0xFFFFF6E0),
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: const Icon(Icons.system_update,
                          color: Color(0xFFC9A227)),
                      title: const Text('Update available — نئی اپڈیٹ'),
                      subtitle: const Text(
                          'A newer Naap with better measurements is ready.'),
                      trailing: const Icon(Icons.download),
                      onTap: () => launchUrl(Uri.parse(kDownloadUrl),
                          mode: LaunchMode.externalApplication),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
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
