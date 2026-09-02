/// Traditional Pakistani tailoring ease ("asan") applied on top of body
/// measurements to produce the stitching naap a tailor cuts against.
///
/// Values are centimeters of ease added to the BODY measurement. They encode
/// common desi-tailor practice and are deliberately kept in one table so a
/// master tailor can review and tune them without touching engine code.
library;

import 'fabric.dart';
import 'models/measurements.dart';

enum GarmentType { shalwarKameez, kurtaPajama, suitTwoPiece, trousersShirt }

enum FitPreference { fitted, regular, loose }

class GarmentDef {
  final GarmentType type;
  final String english;
  final String urdu;
  final List<MeasurementKey> keys;

  const GarmentDef({
    required this.type,
    required this.english,
    required this.urdu,
    required this.keys,
  });
}

const Map<GarmentType, GarmentDef> kGarments = {
  GarmentType.shalwarKameez: GarmentDef(
    type: GarmentType.shalwarKameez,
    english: 'Shalwar Kameez',
    urdu: 'شلوار قمیض',
    keys: [
      MeasurementKey.kameezLength,
      MeasurementKey.shoulder,
      MeasurementKey.chest,
      MeasurementKey.waist,
      MeasurementKey.hip,
      MeasurementKey.sleeveLength,
      MeasurementKey.bicep,
      MeasurementKey.armhole,
      MeasurementKey.wrist,
      MeasurementKey.neck,
      MeasurementKey.hem,
      MeasurementKey.shalwarLength,
      MeasurementKey.ankleOpening,
    ],
  ),
  GarmentType.kurtaPajama: GarmentDef(
    type: GarmentType.kurtaPajama,
    english: 'Kurta Pajama',
    urdu: 'کرتا پاجامہ',
    keys: [
      MeasurementKey.kameezLength,
      MeasurementKey.shoulder,
      MeasurementKey.chest,
      MeasurementKey.waist,
      MeasurementKey.hip,
      MeasurementKey.sleeveLength,
      MeasurementKey.armhole,
      MeasurementKey.neck,
      MeasurementKey.shalwarLength,
      MeasurementKey.thigh,
      MeasurementKey.ankleOpening,
    ],
  ),
  GarmentType.suitTwoPiece: GarmentDef(
    type: GarmentType.suitTwoPiece,
    english: '2-Piece Suit',
    urdu: 'ٹو پیس سوٹ',
    keys: [
      MeasurementKey.chest,
      MeasurementKey.waist,
      MeasurementKey.hip,
      MeasurementKey.shoulder,
      MeasurementKey.sleeveLength,
      MeasurementKey.neck,
      MeasurementKey.bicep,
      MeasurementKey.shalwarLength,
      MeasurementKey.inseam,
      MeasurementKey.thigh,
      MeasurementKey.ankleOpening,
    ],
  ),
  GarmentType.trousersShirt: GarmentDef(
    type: GarmentType.trousersShirt,
    english: 'Shirt & Trousers',
    urdu: 'شرٹ پتلون',
    keys: [
      MeasurementKey.neck,
      MeasurementKey.shoulder,
      MeasurementKey.chest,
      MeasurementKey.waist,
      MeasurementKey.hip,
      MeasurementKey.sleeveLength,
      MeasurementKey.wrist,
      MeasurementKey.shalwarLength,
      MeasurementKey.inseam,
      MeasurementKey.thigh,
      MeasurementKey.ankleOpening,
    ],
  ),
};

/// Ease in cm for [FitPreference.regular]; fitted subtracts, loose adds, per
/// the multipliers below.
const Map<GarmentType, Map<MeasurementKey, double>> _regularEase = {
  GarmentType.shalwarKameez: {
    MeasurementKey.chest: 10.0, // "asan" — kameez is worn loose
    MeasurementKey.waist: 10.0,
    MeasurementKey.hip: 9.0,
    MeasurementKey.shoulder: 1.2,
    MeasurementKey.neck: 1.5,
    MeasurementKey.sleeveLength: 0.0,
    MeasurementKey.bicep: 6.0, // loose kameez sleeve
    MeasurementKey.armhole: 3.0, // baghal asan for arm mobility
    MeasurementKey.wrist: 6.0,
    MeasurementKey.hem: 0.0, // ghera reported as-is; style choice
    MeasurementKey.ankleOpening: 0.0, // paincha is a style number
  },
  GarmentType.kurtaPajama: {
    MeasurementKey.chest: 9.0,
    MeasurementKey.waist: 9.0,
    MeasurementKey.hip: 8.0,
    MeasurementKey.shoulder: 1.0,
    MeasurementKey.neck: 1.5,
    MeasurementKey.armhole: 2.5,
    MeasurementKey.thigh: 8.0,
  },
  GarmentType.suitTwoPiece: {
    MeasurementKey.chest: 8.5, // classic drafting ease for a canvassed jacket
    MeasurementKey.waist: 7.5,
    MeasurementKey.hip: 6.0,
    MeasurementKey.shoulder: 0.6,
    MeasurementKey.bicep: 7.0,
    MeasurementKey.neck: 1.0,
    MeasurementKey.thigh: 7.0,
    MeasurementKey.ankleOpening: 0.0,
  },
  GarmentType.trousersShirt: {
    MeasurementKey.chest: 9.0,
    MeasurementKey.waist: 3.0,
    MeasurementKey.hip: 5.0,
    MeasurementKey.shoulder: 1.0,
    MeasurementKey.neck: 1.2,
    MeasurementKey.wrist: 5.5,
    MeasurementKey.thigh: 7.0,
  },
};

const Map<FitPreference, double> _fitMultiplier = {
  FitPreference.fitted: 0.6,
  FitPreference.regular: 1.0,
  FitPreference.loose: 1.5,
};

/// A single parchi line: the body naap and the stitching naap side by side.
class ParchiLine {
  final MeasurementDef def;
  final double bodyCm;
  final double stitchCm;
  final MeasurementSource source;
  final double confidence;

  const ParchiLine({
    required this.def,
    required this.bodyCm,
    required this.stitchCm,
    required this.source,
    this.confidence = 1.0,
  });
}

class EaseEngine {
  /// Builds the parchi lines for [garment] from body measurements [naap].
  ///
  /// [fabric] adjusts circumference ease for the cloth's rigidity/stretch
  /// (see `fabric.dart`); null means the lawn/cotton baseline.
  static List<ParchiLine> buildParchi(
      Naap naap, GarmentType garment, FitPreference fit,
      {FabricType? fabric}) {
    final def = kGarments[garment]!;
    final ease = _regularEase[garment] ?? const {};
    final mult = _fitMultiplier[fit]!;
    final fabricDef = fabric != null ? kFabrics[fabric] : null;
    final lines = <ParchiLine>[];
    for (final key in def.keys) {
      final v = naap[key];
      if (v == null) continue;
      var e = (ease[key] ?? 0.0) * mult;
      // Fabric delta applies only where the garment already gets ease —
      // style numbers (paincha, ghera) are untouched by cloth choice.
      if (fabricDef != null &&
          (ease[key] ?? 0.0) > 0 &&
          fabricDef.affectedKeys.contains(key)) {
        e += fabricDef.easeDeltaCm;
      }
      lines.add(ParchiLine(
        def: kMeasurementDefs[key]!,
        bodyCm: v.cm,
        stitchCm: v.cm + e,
        source: v.source,
        confidence: v.confidence,
      ));
    }
    return lines;
  }

  /// Chaak (side-slit) length for a kameez: traditionally about a third of the
  /// kameez length, ending just below the waistline.
  static double chaakCm(double kameezLengthCm) => kameezLengthCm / 3.0;
}
