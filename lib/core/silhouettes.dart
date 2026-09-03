/// Trouser silhouette profiles — Phase 2's "dynamic trend layer".
///
/// The body (naap) is immutable truth; a silhouette is a declarative set
/// of offsets applied over it, so fashion cycles (wide-leg today, skinny
/// tomorrow) are one enum away without touching a single measurement.
/// Deterministic and tailor-reviewable, like every table in this app.
library;

import 'models/measurements.dart';

enum SilhouetteProfile { wideFlared, relaxedStraight, slimTapered, skinny }

class SilhouetteDef {
  final SilhouetteProfile profile;
  final String english;
  final String urdu;

  /// Ease added over the measured knee circumference (cm).
  final double kneeEaseCm;

  /// Finished hem opening target (cm) — the paicha the cut aims for.
  final double openingCm;

  /// Length adjustment (cm): positive pools over the shoe, negative crops.
  final double lengthDeltaCm;

  const SilhouetteDef({
    required this.profile,
    required this.english,
    required this.urdu,
    required this.kneeEaseCm,
    required this.openingCm,
    required this.lengthDeltaCm,
  });
}

const Map<SilhouetteProfile, SilhouetteDef> kSilhouettes = {
  SilhouetteProfile.wideFlared: SilhouetteDef(
      profile: SilhouetteProfile.wideFlared,
      english: 'Wide / Flared',
      urdu: 'کھلا / فلیئر',
      kneeEaseCm: 10.0,
      openingCm: 51.0, // ~20" opening, drapes over the shoe
      lengthDeltaCm: 2.5),
  SilhouetteProfile.relaxedStraight: SilhouetteDef(
      profile: SilhouetteProfile.relaxedStraight,
      english: 'Relaxed / Straight',
      urdu: 'سیدھا',
      kneeEaseCm: 7.0,
      openingCm: 43.0, // ~17"
      lengthDeltaCm: 0.0),
  SilhouetteProfile.slimTapered: SilhouetteDef(
      profile: SilhouetteProfile.slimTapered,
      english: 'Slim / Tapered',
      urdu: 'سلم / تنگ',
      kneeEaseCm: 3.5,
      openingCm: 37.0, // ~14.5"
      lengthDeltaCm: -1.0),
  SilhouetteProfile.skinny: SilhouetteDef(
      profile: SilhouetteProfile.skinny,
      english: 'Skinny',
      urdu: 'اسکنی',
      kneeEaseCm: 1.3,
      openingCm: 0, // resolved from the calf feasibility floor
      lengthDeltaCm: -2.5),
};

/// The finished hem opening for a profile given this body — the
/// anatomical feasibility enforcer: no opening may be cut that the foot
/// cannot pass (calf + margin floors everything, skinny is DEFINED by it).
double resolveOpeningCm(SilhouetteDef def, {double? calfCm}) {
  final floor = calfCm != null ? calfCm + 1.3 : 0.0;
  if (def.profile == SilhouetteProfile.skinny) {
    return floor > 0 ? floor : 34.0;
  }
  return def.openingCm > floor ? def.openingCm : floor;
}

/// Which measurement keys a silhouette adjusts (trouser family only).
const Set<MeasurementKey> kSilhouetteKeys = {
  MeasurementKey.knee,
  MeasurementKey.ankleOpening,
  MeasurementKey.shalwarLength,
};
