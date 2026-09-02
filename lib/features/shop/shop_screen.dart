import 'package:flutter/material.dart';

import '../../core/shop_api.dart';
import 'fabric_detail_screen.dart';
import 'fabric_swatch.dart';
import 'orders_screen.dart';

/// Phase 1.5 storefront (beta): verified fabrics from the Naap backend.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late Future<List<ShopFabric>> _catalog;

  // Filter selections (taxonomy ids; null = all). Kept client-side in the
  // same vocabulary the server's /taxonomy serves.
  String? _audience;
  String? _season;
  String? _occasion;

  static const _audiences = {'women': 'Women خواتین', 'men': 'Men حضرات'};
  static const _seasons = {
    'summer': 'Summer گرمی',
    'winter': 'Winter سردی',
    'mid-season': 'Mid-season',
    'all-season': 'All-season',
  };
  static const _occasions = {
    'daily': 'Daily روزمرہ',
    'workwear': 'Workwear',
    'eid': 'Eid عید',
    'dinner-party': 'Dinner/party',
    'mehndi-dholki': 'Mehndi مہندی',
    'nikkah': 'Nikkah نکاح',
    'barat': 'Barat بارات',
    'walima': 'Walima ولیمہ',
    'wedding-guest': 'Wedding guest',
    'bridal': 'Bridal دلہن',
    'groom': 'Groom دولہا',
  };

  @override
  void initState() {
    super.initState();
    _catalog = ShopApi.fetchCatalog();
  }

  void _refetch() {
    final f = <String, String>{
      if (_audience != null) 'audience': _audience!,
      if (_season != null) 'season': _season!,
      if (_occasion != null) 'occasion': _occasion!,
    };
    setState(() => _catalog = ShopApi.fetchCatalog(filters: f));
  }

  Widget _filterBar() {
    DropdownButton<String?> dd(String hint, Map<String, String> opts,
        String? value, void Function(String?) onSel) {
      return DropdownButton<String?>(
        value: value,
        hint: Text(hint),
        underline: const SizedBox.shrink(),
        items: [
          DropdownMenuItem(value: null, child: Text('All $hint')),
          for (final e in opts.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) {
          onSel(v);
          _refetch();
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          dd('audience', _audiences, _audience, (v) => _audience = v),
          const SizedBox(width: 16),
          dd('season', _seasons, _season, (v) => _season = v),
          const SizedBox(width: 16),
          dd('occasion', _occasions, _occasion, (v) => _occasion = v),
        ]),
      ),
    );
  }

  Future<void> _editServer() async {
    final ctrl = TextEditingController(text: await ShopApi.baseUrl());
    if (!mounted) return;
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend server'),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'https://api.naap.app')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (url != null && url.trim().isNotEmpty) {
      await ShopApi.setBaseUrl(url);
      setState(() => _catalog = ShopApi.fetchCatalog());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fabric Shop (beta)'),
        actions: [
          IconButton(
              tooltip: 'My orders',
              icon: const Icon(Icons.receipt_long),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OrdersScreen()))),
          IconButton(icon: const Icon(Icons.dns_outlined), onPressed: _editServer),
        ],
      ),
      body: FutureBuilder<List<ShopFabric>>(
        future: _catalog,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('Shop unreachable.\n${snap.error}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: () => setState(
                            () => _catalog = ShopApi.fetchCatalog()),
                        child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          final fabrics = snap.data!;
          if (fabrics.isEmpty) {
            return Column(children: [
              _filterBar(),
              const Expanded(
                  child: Center(
                      child: Text('No fabrics match these filters.'))),
            ]);
          }
          return Column(children: [
            _filterBar(),
            const SizedBox(height: 4),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.68),
                itemCount: fabrics.length,
                itemBuilder: (context, i) {
                  final f = fabrics[i];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: InkWell(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  FabricDetailScreen(fabric: f))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(fit: StackFit.expand, children: [
                              FabricSwatch(fabric: f, radius: 0),
                              if (f.season != null)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black
                                          .withValues(alpha: 0.45),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: Text(f.season!,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                            ]),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(10, 8, 10, 10),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(f.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5,
                                        height: 1.25)),
                                const SizedBox(height: 3),
                                Text(
                                    '${f.brand ?? 'Wholesale'} · '
                                    '${f.fabricLabel ?? f.composition}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11.5)),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        '\$${f.priceUsd.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1B4D3E))),
                                    Text('${f.meters} m',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                Colors.grey.shade600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}

