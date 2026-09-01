/// Fabric definitions and their effect on ease ("asan").
///
/// The blueprint's "fit & fabric reasoning" implemented the agreed way:
/// a deterministic, tailor-reviewable table — never an LLM in the numeric
/// path (docs/BLUEPRINT.md §AI architecture, rule 3).
///
/// A rigid fabric (raw silk, karandi) needs MORE ease than the baseline; a
/// stretchy knit needs less. `easeDeltaCm` is added on top of the garment's
/// regular ease for the circumference measurements it lists.
library;

import 'models/measurements.dart';

enum FabricType {
  lawn,
  cottonCambric,
  khaddar,
  linen,
  washAndWear,
  rawSilk,
  karandi,
  woolSuiting,
  stretchKnit,
}

class FabricDef {
  final FabricType type;
  final String english;
  final String urdu;

  /// 0.0 = completely rigid, 1.0 = very stretchy. Informational; the ease
  /// math uses [easeDeltaCm], which a master tailor can review directly.
  final double stretch;

  /// Extra ease in cm applied to the listed circumference keys
  /// (positive = cut looser for rigid cloth, negative = trust the stretch).
  final double easeDeltaCm;
  final List<MeasurementKey> affectedKeys;

  const FabricDef({
    required this.type,
    required this.english,
    required this.urdu,
    required this.stretch,
    required this.easeDeltaCm,
    this.affectedKeys = const [
      MeasurementKey.chest,
      MeasurementKey.waist,
      MeasurementKey.hip,
      MeasurementKey.bicep,
      MeasurementKey.thigh,
    ],
  });
}

const Map<FabricType, FabricDef> kFabrics = {
  FabricType.lawn: FabricDef(
      type: FabricType.lawn,
      english: 'Lawn',
      urdu: 'لان',
      stretch: 0.15,
      easeDeltaCm: 0.0), // the baseline: ease tables are tuned for lawn/cotton
  FabricType.cottonCambric: FabricDef(
      type: FabricType.cottonCambric,
      english: 'Cotton / Cambric',
      urdu: 'کاٹن',
      stretch: 0.15,
      easeDeltaCm: 0.0),
  FabricType.khaddar: FabricDef(
      type: FabricType.khaddar,
      english: 'Khaddar',
      urdu: 'کھدر',
      stretch: 0.10,
      easeDeltaCm: 0.6), // coarse weave, minimal give
  FabricType.linen: FabricDef(
      type: FabricType.linen,
      english: 'Linen',
      urdu: 'لینن',
      stretch: 0.08,
      easeDeltaCm: 0.8),
  FabricType.washAndWear: FabricDef(
      type: FabricType.washAndWear,
      english: 'Wash & Wear',
      urdu: 'واش اینڈ ویئر',
      stretch: 0.20,
      easeDeltaCm: 0.0),
  FabricType.rawSilk: FabricDef(
      type: FabricType.rawSilk,
      english: 'Raw Silk',
      urdu: 'خام ریشم',
      stretch: 0.02,
      easeDeltaCm: 1.3), // rigid — seams tear without extra room
  FabricType.karandi: FabricDef(
      type: FabricType.karandi,
      english: 'Karandi',
      urdu: 'کرندی',
      stretch: 0.05,
      easeDeltaCm: 1.0),
  FabricType.woolSuiting: FabricDef(
      type: FabricType.woolSuiting,
      english: 'Wool Suiting',
      urdu: 'اونی کپڑا',
      stretch: 0.12,
      easeDeltaCm: 0.4),
  FabricType.stretchKnit: FabricDef(
      type: FabricType.stretchKnit,
      english: 'Stretch / Knit',
      urdu: 'اسٹریچ',
      stretch: 0.60,
      easeDeltaCm: -1.5), // fabric gives; cutting full ease looks baggy
};
