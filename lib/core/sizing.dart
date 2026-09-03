/// Phase 2 su misura mapping, on-device — mirrors server/app/sizing.py.
///
/// Runs locally so a user can see their EU size without any network call
/// (measurements never have to leave the phone just to see a size).
/// Deterministic — no LLM (docs/BLUEPRINT.md rule 3). Keep in sync with the
/// backend copy.
library;

import 'models/measurements.dart';

class SuMisura {
  final int euSize;
  final int drop;
  final double chestDeltaCm;
  final double waistDeltaCm;
  final double hipDeltaCm;
  final List<String> notes;

  const SuMisura({
    required this.euSize,
    required this.drop,
    required this.chestDeltaCm,
    required this.waistDeltaCm,
    required this.hipDeltaCm,
    required this.notes,
  });
}

/// Women's European ready-to-wear sizing — a different convention entirely
/// from men's suiting (no half-chest, no drop). EU/DE base size from the
/// bust on the standard 4 cm grid (EU 36 ≈ 84 cm bust), hip cross-checked;
/// IT runs +4, FR +2, UK +4 relative to EU/DE. Deterministic conventions —
/// per-BRAND truth still comes from the fit library, garment by garment.
class LadiesSizes {
  final int eu; // German/EU convention (34-52)
  final int it; // Italian (38-56)
  final int fr; // French (36-54)
  final int uk; // UK (6-24)
  final int us; // US (2-20)
  final List<String> notes;

  const LadiesSizes({
    required this.eu,
    required this.it,
    required this.fr,
    required this.uk,
    required this.us,
    required this.notes,
  });
}

LadiesSizes? mapLadiesSizes(Naap naap) {
  final bust = naap[MeasurementKey.chest]?.cm;
  final waist = naap[MeasurementKey.waist]?.cm;
  final hip = naap[MeasurementKey.hip]?.cm;
  if (bust == null || hip == null) return null;
  if (bust < 70 || bust > 140) return null;

  // EU 32 = 76 cm bust, +4 cm per size step.
  var eu = 32 + (((bust - 76.0) / 4.0).round()) * 2;
  eu = eu.clamp(32, 54);

  // Hip-based size on the same grid (EU 32 = 84 cm hip): pear/hourglass
  // figures often need the larger of the two for bottoms.
  var euHip = 32 + (((hip - 84.0) / 4.0).round()) * 2;
  euHip = euHip.clamp(32, 54);

  final notes = <String>[];
  if (euHip > eu) {
    notes.add('Hips size EU $euHip — size bottoms up, or made-to-measure');
  } else if (euHip < eu - 2) {
    notes.add('Hips size EU $euHip — tops and bottoms differ');
  }
  if (waist != null && bust - waist >= 24) {
    notes.add('Defined waist — off-the-rack will gape; MTM fits far better');
  }
  return LadiesSizes(
    eu: eu,
    it: eu + 4,
    fr: eu + 2,
    uk: eu - 28,
    us: eu - 30,
    notes: notes,
  );
}

/// Returns null when the naap lacks chest/waist/hip.
SuMisura? mapSuMisura(Naap naap) {
  final chest = naap[MeasurementKey.chest]?.cm;
  final waist = naap[MeasurementKey.waist]?.cm;
  final hip = naap[MeasurementKey.hip]?.cm;
  if (chest == null || waist == null || hip == null) return null;
  if (chest < 60 || chest > 160) return null;

  var size = 44;
  var best = double.infinity;
  for (var s = 44; s <= 64; s += 2) {
    final d = (s * 2.0 - chest).abs();
    if (d < best) {
      best = d;
      size = s;
    }
  }
  final drop = ((chest - waist) / 2.0).round();
  final nomChest = size * 2.0;
  final notes = <String>[];
  if (drop >= 8) notes.add('Athletic build — jackets need waist suppression');
  if (drop <= 4) notes.add('Comfort fit — size up in slim European cuts');
  if ((chest - nomChest).abs() > 4) {
    notes.add('Between sizes — made-to-measure will fit far better');
  }
  return SuMisura(
    euSize: size,
    drop: drop,
    chestDeltaCm: double.parse((chest - nomChest).toStringAsFixed(1)),
    waistDeltaCm:
        double.parse((waist - (nomChest - 12.0)).toStringAsFixed(1)),
    hipDeltaCm: double.parse((hip - (nomChest + 2.0)).toStringAsFixed(1)),
    notes: notes,
  );
}
