import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/ease.dart';
import 'fabric_swatch.dart';
import '../../core/shop_api.dart';

/// Tri-modal checkout for one fabric: Stitch & Ship, DIY fabric, or
/// measurement-only lives on the results screen already (free parchi).
class FabricDetailScreen extends StatefulWidget {
  final ShopFabric fabric;
  const FabricDetailScreen({super.key, required this.fabric});

  @override
  State<FabricDetailScreen> createState() => _FabricDetailScreenState();
}

class _FabricDetailScreenState extends State<FabricDetailScreen> {
  bool _busy = false;

  Future<void> _order(String mode) async {
    final s = context.read<AppState>();
    if (s.profile.name.isEmpty) {
      _snack('Complete "Your details" on the home screen first.');
      return;
    }

    List<ParchiLine>? parchi;
    if (mode == 'stitch_and_ship') {
      if (!s.hasMeasurements) {
        _snack('Stitch & Ship needs your measurements — run the guided '
            'capture first.');
        return;
      }
      final consent = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Send measurements?'),
          content: const Text(
              'Stitch & Ship sends your measurement NUMBERS (never photos) '
              'to Naap and the assigned master tailor for this order. '
              'Continue?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send numbers')),
          ],
        ),
      );
      if (consent != true) return;
      parchi =
          EaseEngine.buildParchi(s.naap, s.garment, s.fit, fabric: s.fabric);
    }

    final email = await _askEmail();
    if (email == null) return;

    setState(() => _busy = true);
    try {
      final result = await ShopApi.placeOrder(
        mode: mode,
        fabricId: widget.fabric.id,
        garment: kGarments[s.garment]!.english,
        fit: s.fit.name,
        customerName: s.profile.name,
        customerEmail: email,
        parchi: parchi,
      );
      await ShopApi.rememberOrder(PlacedOrder(
        id: result.orderId,
        fabricName: widget.fabric.name,
        mode: mode,
        totalUsd: result.totalUsd,
        createdAt: DateTime.now(),
      ));
      if (!mounted) return;
      if (result.paymentUrl != null) {
        await launchUrl(Uri.parse(result.paymentUrl!),
            mode: LaunchMode.externalApplication);
      }
      _snack('Order ${result.orderId} placed — total '
          '\$${result.totalUsd.toStringAsFixed(2)}. Track it under '
          'My Orders.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Order failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askEmail() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email for order updates'),
        content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'you@example.com')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final v = ctrl.text.trim();
                if (v.contains('@')) Navigator.pop(ctx, v);
              },
              child: const Text('Continue')),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fabric;
    return Scaffold(
      appBar: AppBar(title: Text(f.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AspectRatio(
              aspectRatio: 1.4,
              child: FabricSwatch(fabric: f, radius: 16)),
          const SizedBox(height: 16),
          Text('${f.brand ?? 'Wholesale'} · '
              '${f.fabricLabel ?? f.composition} · ${f.meters} m '
              'unstitched'),
          const SizedBox(height: 8),
          Text('\$${f.priceUsd.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (f.description.isNotEmpty) Text(f.description),
          const SizedBox(height: 24),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else ...[
            FilledButton.icon(
              onPressed: () => _order('stitch_and_ship'),
              icon: const Icon(Icons.content_cut),
              label: const Text('Stitch & Ship — fabric + master tailor'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _order('diy_fabric'),
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Ship me the fabric — I have my own tailor'),
            ),
            const SizedBox(height: 16),
            Text(
              'Stitch & Ship sends only your measurement numbers (with your '
              'consent) — never photos. Your own tailor? Pair the fabric '
              'with the free WhatsApp parchi from the measurement screen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
