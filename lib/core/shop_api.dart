/// Client for the Naap backend (server/). Used only by the Shop feature —
/// the measurement flow never touches the network.
///
/// Measurements are included in a request ONLY for stitch & ship orders and
/// only after the explicit consent dialog in the checkout UI.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ease.dart';

class ShopFabric {
  final String id;
  final String name;
  final String? brand;
  final String composition;
  final String description;
  final double priceUsd;
  final double meters;
  final String? imageUrl;
  final String? fabricLabel;
  final String? season;
  final List<String> occasions;

  const ShopFabric({
    required this.id,
    required this.name,
    this.brand,
    required this.composition,
    required this.description,
    required this.priceUsd,
    required this.meters,
    this.imageUrl,
    this.fabricLabel,
    this.season,
    this.occasions = const [],
  });

  factory ShopFabric.fromJson(Map<String, dynamic> j) => ShopFabric(
        id: j['id'] as String,
        name: j['name'] as String,
        brand: j['brand'] as String?,
        composition: j['composition'] as String? ?? 'other',
        description: j['description'] as String? ?? '',
        priceUsd: (j['price_usd'] as num).toDouble(),
        meters: (j['meters'] as num?)?.toDouble() ?? 5.0,
        imageUrl: j['image_url'] as String?,
        fabricLabel: j['fabric_label'] as String?,
        season: j['season'] as String?,
        occasions: [
          for (final o in (j['occasions'] as List<dynamic>? ?? [])) '$o'
        ],
      );
}

class OrderResult {
  final String orderId;
  final double totalUsd;
  final String? paymentUrl;

  const OrderResult(
      {required this.orderId, required this.totalUsd, this.paymentUrl});
}

/// A locally remembered order (ids only live on this phone).
class PlacedOrder {
  final String id;
  final String fabricName;
  final String mode;
  final double totalUsd;
  final DateTime createdAt;

  const PlacedOrder({
    required this.id,
    required this.fabricName,
    required this.mode,
    required this.totalUsd,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fabricName': fabricName,
        'mode': mode,
        'totalUsd': totalUsd,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PlacedOrder.fromJson(Map<String, dynamic> j) => PlacedOrder(
        id: j['id'] as String,
        fabricName: j['fabricName'] as String? ?? '',
        mode: j['mode'] as String? ?? '',
        totalUsd: (j['totalUsd'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Live order status from the backend.
class OrderStatus {
  final String status;
  final List<String> history;
  final double totalUsd;

  const OrderStatus(
      {required this.status, required this.history, required this.totalUsd});
}

class ShopApi {
  static const _kBaseUrl = 'naap.backendUrl';
  static const _kOrders = 'naap.placedOrders';

  static Future<List<PlacedOrder>> localOrders() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kOrders);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final j in list) PlacedOrder.fromJson(j as Map<String, dynamic>)
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> rememberOrder(PlacedOrder o) async {
    final sp = await SharedPreferences.getInstance();
    final current = await localOrders();
    current.insert(0, o);
    await sp.setString(
        _kOrders, jsonEncode([for (final x in current) x.toJson()]));
  }

  /// Price breakdown before ordering — no surprises at checkout.
  static Future<Map<String, dynamic>> quote(
      {required String mode, String? fabricId}) async {
    final base = await baseUrl();
    final resp = await http
        .post(Uri.parse('$base/orders/quote'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'mode': mode, 'fabric_id': fabricId}))
        .timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) {
      throw Exception('Quote failed (HTTP ${resp.statusCode})');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future<OrderStatus> fetchOrder(String orderId) async {
    final base = await baseUrl();
    final resp = await http
        .get(Uri.parse('$base/orders/$orderId'))
        .timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) {
      throw Exception('Order lookup failed (HTTP ${resp.statusCode})');
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    return OrderStatus(
      status: j['status'] as String? ?? 'unknown',
      history: [for (final h in (j['history'] as List<dynamic>? ?? [])) '$h'],
      totalUsd: (j['total_usd'] as num?)?.toDouble() ?? 0,
    );
  }
  // Production backend (AWS Lightsail, docs/DEPLOY.md); overridable in the
  // shop UI — use http://10.0.2.2:8000 against a dev server on an emulator.
  static const defaultBaseUrl =
      'https://naap-api.m9vte9fmk66k4.us-west-2.cs.amazonlightsail.com';

  static Future<String> baseUrl() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kBaseUrl) ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kBaseUrl, url.trim());
  }

  /// [filters] maps /catalog query params (audience, season, occasion,
  /// buying_option, brand_id, category_id) to taxonomy ids.
  static Future<List<ShopFabric>> fetchCatalog(
      {Map<String, String>? filters}) async {
    final base = await baseUrl();
    final uri = Uri.parse('$base/catalog').replace(
        queryParameters:
            (filters == null || filters.isEmpty) ? null : filters);
    final resp =
        await http.get(uri).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) {
      throw Exception('Catalog unavailable (HTTP ${resp.statusCode})');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    return [
      for (final j in list) ShopFabric.fromJson(j as Map<String, dynamic>)
    ];
  }

  /// [parchi] must be non-null ONLY for stitch & ship, after consent.
  static Future<OrderResult> placeOrder({
    required String mode,
    String? fabricId,
    required String garment,
    required String fit,
    required String customerName,
    required String customerEmail,
    String? shipTo,
    List<ParchiLine>? parchi,
  }) async {
    final base = await baseUrl();
    final body = {
      'mode': mode,
      'fabric_id': fabricId,
      'garment': garment,
      'fit': fit,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'ship_to': shipTo,
      'parchi': [
        if (parchi != null)
          for (final l in parchi)
            {
              'key': l.def.key.name,
              'english': l.def.english,
              'urdu': l.def.urdu,
              'tailor_term': l.def.tailorTerm,
              'body_cm': l.bodyCm,
              'stitch_cm': l.stitchCm,
            }
      ],
    };
    final resp = await http
        .post(Uri.parse('$base/orders'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw Exception('Order failed (HTTP ${resp.statusCode}): ${resp.body}');
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    final order = j['order'] as Map<String, dynamic>;
    return OrderResult(
      orderId: order['id'] as String,
      totalUsd: (order['total_usd'] as num).toDouble(),
      paymentUrl: j['payment_url'] as String?,
    );
  }
}
