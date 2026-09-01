import 'package:flutter/material.dart';

import '../../core/shop_api.dart';
import 'fabric_detail_screen.dart';

/// Phase 1.5 storefront (beta): verified fabrics from the Naap backend.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late Future<List<ShopFabric>> _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = ShopApi.fetchCatalog();
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
            return const Center(child: Text('No fabrics listed yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: fabrics.length,
            itemBuilder: (context, i) {
              final f = fabrics[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F1EC),
                      child: Icon(Icons.checkroom, color: Color(0xFF1B4D3E))),
                  title: Text(f.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${f.brand ?? 'Wholesale'} · ${f.composition} · ${f.meters} m'),
                  trailing: Text('\$${f.priceUsd.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => FabricDetailScreen(fabric: f))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
