import 'package:flutter/material.dart';

import '../../core/shop_api.dart';

/// Order tracking: ids are remembered only on this phone; tapping an order
/// fetches its live status from the backend (numbers only, as always).
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<PlacedOrder>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = ShopApi.localOrders();
  }

  static const _statusLabels = {
    'placed': ('Placed', 'موصول', Colors.blueGrey),
    'paid': ('Paid', 'ادائیگی ہو گئی', Colors.teal),
    'fabric_cut': ('Fabric cut', 'کپڑا کٹ گیا', Color(0xFF1B4D3E)),
    'stitching': ('Stitching', 'سلائی جاری', Color(0xFF1B4D3E)),
    'quality_check': ('Quality check', 'معیار کی جانچ', Color(0xFFC9A227)),
    'shipped': ('Shipped', 'روانہ', Color(0xFF1B4D3E)),
    'delivered': ('Delivered', 'موصول ہو گیا', Colors.green),
    'cancelled': ('Cancelled', 'منسوخ', Colors.red),
  };

  Future<void> _showStatus(PlacedOrder o) async {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => FutureBuilder<OrderStatus>(
        future: ShopApi.fetchOrder(o.id),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return SizedBox(
              height: 220,
              child: Center(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not reach the order right now.\n'
                    '${snap.error}'),
              )),
            );
          }
          final st = snap.data!;
          final (en, ur, color) = _statusLabels[st.status] ??
              (st.status, '', Colors.blueGrey);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text('Order ${o.id}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16))),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999)),
                    child: Text('$en  $ur',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 12),
                for (final h in st.history.reversed.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.circle,
                            size: 8, color: Color(0xFF1B4D3E)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(h,
                                style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: FutureBuilder<List<PlacedOrder>>(
        future: _orders,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snap.data ?? [];
          if (orders.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                  'No orders yet.\nOrders you place in the Fabric Shop '
                  'appear here with live stitching status.',
                  textAlign: TextAlign.center),
            ));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final o = orders[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F1EC),
                      child:
                          Icon(Icons.receipt_long, color: Color(0xFF1B4D3E))),
                  title: Text(o.fabricName.isEmpty
                      ? 'Order ${o.id}'
                      : o.fabricName),
                  subtitle: Text(
                      '${o.mode.replaceAll('_', ' ')} · '
                      '${o.createdAt.toLocal().toString().substring(0, 16)}'),
                  trailing: Text('\$${o.totalUsd.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  onTap: () => _showStatus(o),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
