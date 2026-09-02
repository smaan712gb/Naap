/// Per-user learning (v1.5) — Naap learns from your tape corrections.
///
/// When the user manually corrects an AI-produced measurement, the delta
/// (their number minus the AI's) is remembered per measurement key as an
/// exponentially weighted average. The NEXT capture applies that bounded
/// correction to the same measurement before showing results.
///
/// Deterministic by design (product law: no LLM in the numeric path), fully
/// on-device, and manual edits always win — a correction only ever adjusts
/// AI values, never a number the user typed.
library;

import 'dart:convert';

import 'models/measurements.dart';

class PersonalCalibration {
  /// EWMA of (manual − AI) per key, in cm.
  final Map<MeasurementKey, double> deltas;

  PersonalCalibration({Map<MeasurementKey, double>? deltas})
      : deltas = deltas ?? {};

  /// How much a single correction moves the stored delta (0..1).
  static const double blend = 0.5;

  /// A correction can never exceed this magnitude — one wild edit (typo,
  /// wrong unit) must not poison future captures.
  static const double maxDeltaCm = 6.0;

  /// Record a manual edit of an AI value.
  void learn(MeasurementKey key, {required double aiCm, required double manualCm}) {
    final delta = (manualCm - aiCm).clamp(-maxDeltaCm, maxDeltaCm);
    final prev = deltas[key];
    final next = prev == null ? delta : prev * (1 - blend) + delta * blend;
    deltas[key] = next.clamp(-maxDeltaCm, maxDeltaCm).toDouble();
  }

  /// Apply stored corrections to a fresh engine result, AI values only.
  void apply(Naap naap) {
    for (final entry in deltas.entries) {
      final v = naap[entry.key];
      if (v == null || v.source == MeasurementSource.manual) continue;
      naap.set(
          entry.key,
          MeasurementValue(v.cm + entry.value,
              source: v.source,
              // A learned value is more trustworthy than a raw one.
              confidence: (v.confidence + 0.15).clamp(0.0, 0.95)));
    }
  }

  String toJsonString() => jsonEncode(
      {for (final e in deltas.entries) e.key.name: e.value});

  factory PersonalCalibration.fromJsonString(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return PersonalCalibration(deltas: {
      for (final e in j.entries)
        if (MeasurementKey.values.any((k) => k.name == e.key))
          MeasurementKey.values.firstWhere((k) => k.name == e.key):
              (e.value as num).toDouble(),
    });
  }
}
