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
  // Summer
  lawn,
  embroideredLawn,
  cottonCambric,
  chiffon,
  // Transitional (spring/autumn)
  viscose,
  washAndWear,
  // Winter
  khaddar,
  linen,
  marina,
  dhanak,
  pashmina,
  woolSuiting,
  velvet,
  // Weddings / bridal
  rawSilk,
  karandi,
  jamawar,
  organza,
  netTissue,
  // Eid / festive
  jacquard,
  cottonNet,
  // Catalog-review additions (2026-09-02)
  voile,
  seersucker,
  cottonDobby,
  georgette,
  satin,
  silk,
  boski,
  cottonLatha,
  // Modern
  stretchKnit,
}

/// When the fabric is typically worn — shop-filter metadata, never math.
enum FabricSeason { summer, winter, transitional, allSeason }

/// The occasion a fabric usually dresses — shop-filter metadata, never math.
enum FabricOccasion { daily, semiFormal, formal, bridal, festive }

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

  final FabricSeason season;
  final FabricOccasion occasion;

  const FabricDef({
    required this.type,
    required this.english,
    required this.urdu,
    required this.stretch,
    required this.easeDeltaCm,
    this.season = FabricSeason.allSeason,
    this.occasion = FabricOccasion.daily,
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
  // ---- Summer ----
  FabricType.lawn: FabricDef(
      type: FabricType.lawn,
      english: 'Lawn',
      urdu: 'لان',
      stretch: 0.15,
      easeDeltaCm: 0.0, // the baseline: ease tables are tuned for lawn/cotton
      season: FabricSeason.summer),
  FabricType.embroideredLawn: FabricDef(
      type: FabricType.embroideredLawn,
      english: 'Embroidered Lawn',
      urdu: 'کڑھائی والی لان',
      stretch: 0.08, // heavy threadwork removes the weave's give
      easeDeltaCm: 0.5,
      season: FabricSeason.summer,
      occasion: FabricOccasion.festive),
  FabricType.cottonCambric: FabricDef(
      type: FabricType.cottonCambric,
      english: 'Cotton / Cambric',
      urdu: 'کاٹن',
      stretch: 0.15,
      easeDeltaCm: 0.0,
      season: FabricSeason.transitional),
  FabricType.chiffon: FabricDef(
      type: FabricType.chiffon,
      english: 'Chiffon',
      urdu: 'شفون',
      stretch: 0.12, // drapes rather than resists; usually lined
      easeDeltaCm: 0.0,
      season: FabricSeason.summer,
      occasion: FabricOccasion.semiFormal),
  // ---- Transitional ----
  FabricType.viscose: FabricDef(
      type: FabricType.viscose,
      english: 'Viscose',
      urdu: 'وسکوز',
      stretch: 0.25, // silk-like drape with mild give
      easeDeltaCm: 0.0,
      season: FabricSeason.transitional),
  FabricType.washAndWear: FabricDef(
      type: FabricType.washAndWear,
      english: 'Wash & Wear',
      urdu: 'واش اینڈ ویئر',
      stretch: 0.20,
      easeDeltaCm: 0.0),
  // ---- Winter ----
  FabricType.khaddar: FabricDef(
      type: FabricType.khaddar,
      english: 'Khaddar',
      urdu: 'کھدر',
      stretch: 0.10,
      easeDeltaCm: 0.6, // coarse weave, minimal give
      season: FabricSeason.winter),
  FabricType.linen: FabricDef(
      type: FabricType.linen,
      english: 'Linen',
      urdu: 'لینن',
      stretch: 0.08,
      easeDeltaCm: 0.8,
      season: FabricSeason.winter),
  FabricType.marina: FabricDef(
      type: FabricType.marina,
      english: 'Marina',
      urdu: 'میرینا',
      stretch: 0.20, // soft blended weave, drapes with some give
      easeDeltaCm: 0.2,
      season: FabricSeason.winter),
  FabricType.dhanak: FabricDef(
      type: FabricType.dhanak,
      english: 'Dhanak',
      urdu: 'دھنک',
      stretch: 0.20,
      easeDeltaCm: 0.2,
      season: FabricSeason.winter),
  FabricType.pashmina: FabricDef(
      type: FabricType.pashmina,
      english: 'Pashmina',
      urdu: 'پشمینہ',
      stretch: 0.15,
      easeDeltaCm: 0.4,
      season: FabricSeason.winter,
      occasion: FabricOccasion.formal),
  FabricType.woolSuiting: FabricDef(
      type: FabricType.woolSuiting,
      english: 'Wool Suiting',
      urdu: 'اونی کپڑا',
      stretch: 0.12,
      easeDeltaCm: 0.4,
      season: FabricSeason.winter,
      occasion: FabricOccasion.formal),
  FabricType.velvet: FabricDef(
      type: FabricType.velvet,
      english: 'Velvet',
      urdu: 'مخمل',
      stretch: 0.05, // thick pile, effectively no give
      easeDeltaCm: 1.2,
      season: FabricSeason.winter,
      occasion: FabricOccasion.bridal),
  // ---- Weddings / bridal ----
  FabricType.rawSilk: FabricDef(
      type: FabricType.rawSilk,
      english: 'Raw Silk (Katan)',
      urdu: 'خام ریشم',
      stretch: 0.02,
      easeDeltaCm: 1.3, // rigid — seams tear without extra room
      occasion: FabricOccasion.bridal),
  FabricType.karandi: FabricDef(
      type: FabricType.karandi,
      english: 'Karandi',
      urdu: 'کرندی',
      stretch: 0.05,
      easeDeltaCm: 1.0,
      season: FabricSeason.winter,
      occasion: FabricOccasion.formal),
  FabricType.jamawar: FabricDef(
      type: FabricType.jamawar,
      english: 'Jamawar (Banarsi)',
      urdu: 'جام وار',
      stretch: 0.03, // dense silk brocade
      easeDeltaCm: 1.4,
      occasion: FabricOccasion.bridal),
  FabricType.organza: FabricDef(
      type: FabricType.organza,
      english: 'Organza',
      urdu: 'آرگنزا',
      stretch: 0.02, // crisp and structural — holds volume, gives nothing
      easeDeltaCm: 1.8,
      occasion: FabricOccasion.bridal),
  FabricType.netTissue: FabricDef(
      type: FabricType.netTissue,
      english: 'Net / Tissue',
      urdu: 'نیٹ / ٹشو',
      stretch: 0.10, // sheer overlays over lining
      easeDeltaCm: 1.0,
      occasion: FabricOccasion.bridal),
  // ---- Eid / festive ----
  FabricType.jacquard: FabricDef(
      type: FabricType.jacquard,
      english: 'Jacquard',
      urdu: 'جیکارڈ',
      stretch: 0.08, // raised woven pattern stiffens the hand
      easeDeltaCm: 0.8,
      occasion: FabricOccasion.festive),
  FabricType.cottonNet: FabricDef(
      type: FabricType.cottonNet,
      english: 'Cotton Net',
      urdu: 'کاٹن نیٹ',
      stretch: 0.12,
      easeDeltaCm: 0.6,
      season: FabricSeason.summer,
      occasion: FabricOccasion.festive),
  // ---- Catalog-review additions ----
  FabricType.voile: FabricDef(
      type: FabricType.voile,
      english: 'Voile',
      urdu: 'وائل',
      stretch: 0.12,
      easeDeltaCm: 0.0,
      season: FabricSeason.summer),
  FabricType.seersucker: FabricDef(
      type: FabricType.seersucker,
      english: 'Seersucker',
      urdu: 'سیرسکر',
      stretch: 0.15, // puckered weave has a little mechanical give
      easeDeltaCm: 0.2,
      season: FabricSeason.summer),
  FabricType.cottonDobby: FabricDef(
      type: FabricType.cottonDobby,
      english: 'Cotton Dobby',
      urdu: 'کاٹن ڈوبی',
      stretch: 0.12,
      easeDeltaCm: 0.2,
      season: FabricSeason.summer),
  FabricType.georgette: FabricDef(
      type: FabricType.georgette,
      english: 'Georgette',
      urdu: 'جارجٹ',
      stretch: 0.15, // crinkled drape, usually lined
      easeDeltaCm: 0.0,
      occasion: FabricOccasion.formal),
  FabricType.satin: FabricDef(
      type: FabricType.satin,
      english: 'Satin',
      urdu: 'ساٹن',
      stretch: 0.10,
      easeDeltaCm: 0.2,
      occasion: FabricOccasion.formal),
  FabricType.silk: FabricDef(
      type: FabricType.silk,
      english: 'Silk',
      urdu: 'ریشم',
      stretch: 0.10,
      easeDeltaCm: 0.3,
      occasion: FabricOccasion.formal),
  FabricType.boski: FabricDef(
      type: FabricType.boski,
      english: 'Boski', // shopping label — often blended, not pure silk
      urdu: 'بوسکی',
      stretch: 0.12,
      easeDeltaCm: 0.3,
      occasion: FabricOccasion.festive),
  FabricType.cottonLatha: FabricDef(
      type: FabricType.cottonLatha,
      english: 'Cotton Latha',
      urdu: 'لٹھا',
      stretch: 0.12,
      easeDeltaCm: 0.0,
      season: FabricSeason.summer),
  // ---- Modern ----
  FabricType.stretchKnit: FabricDef(
      type: FabricType.stretchKnit,
      english: 'Stretch / Knit',
      urdu: 'اسٹریچ',
      stretch: 0.60,
      easeDeltaCm: -1.5), // fabric gives; cutting full ease looks baggy
};
