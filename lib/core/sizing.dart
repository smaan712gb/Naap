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
