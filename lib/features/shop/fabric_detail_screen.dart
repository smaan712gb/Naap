import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/ease.dart';
import '../../core/models/profile.dart';
import '../../core/sizing.dart';
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

  /// Fit preview for made-to-measure garments: swapping fits swaps the
  /// photo so the customer SEES the silhouette. The stitching numbers stay
  /// in the deterministic ease engine.
  String _fitPreview = 'regular';

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

    final checkout = await _confirmCheckout(mode);
    if (checkout == null) return;

    setState(() => _busy = true);
    try {
      final result = await ShopApi.placeOrder(
        mode: mode,
        fabricId: widget.fabric.id,
        garment: kGarments[s.garment]!.english,
        fit: s.fit.name,
        customerName: s.profile.name,
        customerEmail: checkout.email,
        shipTo: checkout.shipTo,
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

  /// Checkout confirmation: live price breakdown, email, and — for modes
  /// that ship — the delivery address. No surprises after the tap.
  Future<({String email, String? shipTo})?> _confirmCheckout(
      String mode) async {
    final needsShipping = mode != 'measurement_only';
    final emailCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    return showDialog<({String email, String? shipTo})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm your order'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FutureBuilder<Map<String, dynamic>>(
                future: ShopApi.quote(mode: mode, fabricId: widget.fabric.id),
                builder: (ctx, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                            child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))));
                  }
                  if (snap.hasError) {
                    return Text('Could not fetch pricing: ${snap.error}',
                        style: const TextStyle(color: Colors.orange));
                  }
                  final q = snap.data!;
                  Widget row(String label, num v, {bool bold = false}) =>
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(label,
                                style: TextStyle(
                                    fontWeight: bold
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                            Text('\$${v.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontWeight: bold
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                          ],
                        ),
                      );
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE8F1EC),
                        borderRadius: BorderRadius.circular(10)),
                    child: Column(children: [
                      if ((q['fabric_usd'] as num) > 0)
                        row('Fabric', q['fabric_usd'] as num),
                      if ((q['service_usd'] as num) > 0)
                        row('Stitching & service', q['service_usd'] as num),
                      if ((q['shipping_usd'] as num) > 0)
                        row('Worldwide shipping', q['shipping_usd'] as num),
                      const Divider(height: 12),
                      row('Total', q['total_usd'] as num, bold: true),
                    ]),
                  );
                },
              ),
              const SizedBox(height: 14),
              TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email for order updates',
                      hintText: 'you@example.com',
                      border: OutlineInputBorder())),
              if (needsShipping) ...[
                const SizedBox(height: 10),
                TextField(
                    controller: addrCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Shipping address',
                        hintText: 'Name, street, city, country',
                        border: OutlineInputBorder())),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final email = emailCtrl.text.trim();
                final addr = addrCtrl.text.trim();
                if (!email.contains('@')) return;
                if (needsShipping && addr.length < 10) return;
                Navigator.pop(ctx,
                    (email: email, shipTo: needsShipping ? addr : null));
              },
              child: const Text('Place order')),
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
              aspectRatio: f.isMtm ? 0.9 : 1.4,
              child: FabricSwatch(
                  fabric: f,
                  radius: 16,
                  imageUrlOverride:
                      f.isMtm ? f.fitImageUrl(_fitPreview) : null)),
          if (f.isMtm) ...[
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fitted', label: Text('Fitted')),
                ButtonSegment(value: 'regular', label: Text('Regular')),
                ButtonSegment(value: 'loose', label: Text('Loose')),
              ],
              selected: {_fitPreview},
              onSelectionChanged: (s) =>
                  setState(() => _fitPreview = s.first),
            ),
            const SizedBox(height: 4),
            Builder(builder: (context) {
              final s = context.watch<AppState>();
              final label = s.hasMeasurements
                  ? sizeLabel(s.naap,
                      female: s.profile.bodyType == BodyType.female)
                  : null;
              return Text(
                  label != null
                      ? 'Will be cut to your naap ($label) — the fits '
                          'above show the silhouette, your scan sets the '
                          'numbers.'
                      : 'See the cut change — your exact numbers come '
                          'from your own scan.',
                  style: Theme.of(context).textTheme.bodySmall);
            }),
          ],
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
