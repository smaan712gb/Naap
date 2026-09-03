import 'package:flutter/material.dart';

import '../../core/shop_api.dart';

/// Product image with a graceful fallback: when a fabric has no photo yet
/// (rights-safe imagery arrives via partnerships), a deterministic woven
/// gradient in the fabric's own hue stands in — premium, never broken.
class FabricSwatch extends StatelessWidget {
  final ShopFabric fabric;
  final double? size;
  final double radius;

  /// Optional override (fit-preview variants); falls back to the fabric's
  /// own image, then the woven gradient, if it fails to load.
  final String? imageUrlOverride;

  const FabricSwatch(
      {super.key,
      required this.fabric,
      this.size,
      this.radius = 12,
      this.imageUrlOverride});

  @override
  Widget build(BuildContext context) {
    final placeholder = _placeholder();
    final base = fabric.imageUrl;
    final baseImage = base == null
        ? placeholder
        : Image.network(base,
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
    final child = imageUrlOverride == null
        ? baseImage
        : Image.network(imageUrlOverride!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => baseImage);
    final clipped = ClipRRect(
        borderRadius: BorderRadius.circular(radius), child: child);
    return size == null
        ? clipped
        : SizedBox(width: size, height: size, child: clipped);
  }

  Widget _placeholder() {
    // Hue derived from the composition name — stable per fabric type.
    final hue = (fabric.composition.codeUnits.fold(0, (a, b) => a + b) * 37)
            .toDouble() %
        360;
    final light = HSLColor.fromAHSL(1, hue, 0.35, 0.66).toColor();
    final dark = HSLColor.fromAHSL(1, hue, 0.42, 0.40).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [light, dark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Center(
        child: Text(
          fabric.name.isEmpty ? '' : fabric.name[0].toUpperCase(),
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 42,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

Widget fabricChip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
