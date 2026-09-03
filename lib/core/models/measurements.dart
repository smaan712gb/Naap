/// Canonical measurement vocabulary for Naap.
///
/// Every measurement carries an English label, an Urdu label (the term a
/// Pakistani tailor actually uses on a parchi), and a unit-agnostic value
/// stored internally in centimeters.
library;

enum MeasurementSource { landmarks, silhouette, regression, manual }

enum MeasurementKey {
  height,
  neck,
  shoulder, // Teera
  chest, // Chaati
  waist, // Kamar (natural waist — kameez fit)
  trouserWaist, // Belt — where the trouser/pajama waistband sits
  belly, // Pait — widest stomach, jacket buttoning
  hip, // Hip / Seat
  sleeveLength, // Baazu
  bicep,
  forearm, // below the elbow — fitted sleeves
  armhole, // Baghal
  wrist, // Kalai
  kameezLength, // Qameez Lambai
  shalwarLength, // Shalwar Lambai
  inseam,
  thigh, // Raan
  calf, // Pindli — floors the minimum paicha on trousers
  ankleOpening, // Paincha
  hem, // Ghera (kameez bottom sweep)
  jacketLength, // Coat Lambai — nape to hip, European jackets
  frontChest, // front chest width, armpit to armpit (drafting)
  backWidth, // back width across the blades (drafting)
}

class MeasurementDef {
  final MeasurementKey key;
  final String english;
  final String urdu;
  final String tailorTerm; // romanized term tailors use verbally
  final bool isCircumference;

  const MeasurementDef({
    required this.key,
    required this.english,
    required this.urdu,
    required this.tailorTerm,
    this.isCircumference = false,
  });
}

const Map<MeasurementKey, MeasurementDef> kMeasurementDefs = {
  MeasurementKey.height: MeasurementDef(
      key: MeasurementKey.height,
      english: 'Height',
      urdu: 'قد',
      tailorTerm: 'Qad'),
  MeasurementKey.neck: MeasurementDef(
      key: MeasurementKey.neck,
      english: 'Neck',
      urdu: 'گلا',
      tailorTerm: 'Gala',
      isCircumference: true),
  MeasurementKey.shoulder: MeasurementDef(
      key: MeasurementKey.shoulder,
      english: 'Shoulder',
      urdu: 'تیرا',
      tailorTerm: 'Teera'),
  MeasurementKey.chest: MeasurementDef(
      key: MeasurementKey.chest,
      english: 'Chest',
      urdu: 'چھاتی',
      tailorTerm: 'Chaati',
      isCircumference: true),
  MeasurementKey.waist: MeasurementDef(
      key: MeasurementKey.waist,
      english: 'Waist',
      urdu: 'کمر',
      tailorTerm: 'Kamar',
      isCircumference: true),
  MeasurementKey.hip: MeasurementDef(
      key: MeasurementKey.hip,
      english: 'Hip / Seat',
      urdu: 'ہپ',
      tailorTerm: 'Hip',
      isCircumference: true),
  MeasurementKey.sleeveLength: MeasurementDef(
      key: MeasurementKey.sleeveLength,
      english: 'Sleeve length',
      urdu: 'بازو',
      tailorTerm: 'Baazu'),
  MeasurementKey.bicep: MeasurementDef(
      key: MeasurementKey.bicep,
      english: 'Bicep',
      urdu: 'ڈولا',
      tailorTerm: 'Dola',
      isCircumference: true),
  MeasurementKey.forearm: MeasurementDef(
      key: MeasurementKey.forearm,
      english: 'Forearm',
      urdu: 'بازو (کہنی کے نیچے)',
      tailorTerm: 'Forearm',
      isCircumference: true),
  MeasurementKey.calf: MeasurementDef(
      key: MeasurementKey.calf,
      english: 'Calf',
      urdu: 'پنڈلی',
      tailorTerm: 'Pindli',
      isCircumference: true),
  MeasurementKey.armhole: MeasurementDef(
      key: MeasurementKey.armhole,
      english: 'Armhole',
      urdu: 'بغل',
      tailorTerm: 'Baghal',
      isCircumference: true),
  MeasurementKey.trouserWaist: MeasurementDef(
      key: MeasurementKey.trouserWaist,
      english: 'Trouser waist',
      urdu: 'پتلون کمر',
      tailorTerm: 'Belt',
      isCircumference: true),
  MeasurementKey.belly: MeasurementDef(
      key: MeasurementKey.belly,
      english: 'Belly / Stomach',
      urdu: 'پیٹ',
      tailorTerm: 'Pait',
      isCircumference: true),
  MeasurementKey.jacketLength: MeasurementDef(
      key: MeasurementKey.jacketLength,
      english: 'Jacket length',
      urdu: 'کوٹ لمبائی',
      tailorTerm: 'Coat Lambai'),
  MeasurementKey.frontChest: MeasurementDef(
      key: MeasurementKey.frontChest,
      english: 'Front chest width',
      urdu: 'سامنے چھاتی',
      tailorTerm: 'Front Chest'),
  MeasurementKey.backWidth: MeasurementDef(
      key: MeasurementKey.backWidth,
      english: 'Back width',
      urdu: 'پشت چوڑائی',
      tailorTerm: 'Pusht'),
  MeasurementKey.wrist: MeasurementDef(
      key: MeasurementKey.wrist,
      english: 'Wrist / Cuff',
      urdu: 'کلائی',
      tailorTerm: 'Kalai',
      isCircumference: true),
  MeasurementKey.kameezLength: MeasurementDef(
      key: MeasurementKey.kameezLength,
      english: 'Kameez length',
      urdu: 'قمیض لمبائی',
      tailorTerm: 'Qameez Lambai'),
  MeasurementKey.shalwarLength: MeasurementDef(
      key: MeasurementKey.shalwarLength,
      english: 'Shalwar / Trouser length',
      urdu: 'شلوار لمبائی',
      tailorTerm: 'Shalwar Lambai'),
  MeasurementKey.inseam: MeasurementDef(
      key: MeasurementKey.inseam,
      english: 'Inseam',
      urdu: 'اندرونی لمبائی',
      tailorTerm: 'Inseam'),
  MeasurementKey.thigh: MeasurementDef(
      key: MeasurementKey.thigh,
      english: 'Thigh',
      urdu: 'ران',
      tailorTerm: 'Raan',
      isCircumference: true),
  MeasurementKey.ankleOpening: MeasurementDef(
      key: MeasurementKey.ankleOpening,
      english: 'Ankle opening',
      urdu: 'پائنچہ',
      tailorTerm: 'Paincha',
      isCircumference: true),
  MeasurementKey.hem: MeasurementDef(
      key: MeasurementKey.hem,
      english: 'Hem sweep',
      urdu: 'گھیرا',
      tailorTerm: 'Ghera',
      isCircumference: true),
};

class MeasurementValue {
  final double cm;
  final MeasurementSource source;

  /// 0..1 — how much the engine trusts this number. Manual edits are 1.0.
  final double confidence;

  const MeasurementValue(this.cm,
      {this.source = MeasurementSource.manual, this.confidence = 1.0});

  MeasurementValue copyWith({double? cm, MeasurementSource? source, double? confidence}) =>
      MeasurementValue(cm ?? this.cm,
          source: source ?? this.source, confidence: confidence ?? this.confidence);

  double get inches => cm / 2.54;

  Map<String, dynamic> toJson() =>
      {'cm': cm, 'source': source.name, 'confidence': confidence};

  factory MeasurementValue.fromJson(Map<String, dynamic> j) => MeasurementValue(
        (j['cm'] as num).toDouble(),
        source: MeasurementSource.values
            .firstWhere((s) => s.name == j['source'], orElse: () => MeasurementSource.manual),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 1.0,
      );
}

/// A full set of body measurements ("naap") for one person.
class Naap {
  final Map<MeasurementKey, MeasurementValue> values;

  Naap(this.values);

  Naap.empty() : values = {};

  MeasurementValue? operator [](MeasurementKey k) => values[k];

  void set(MeasurementKey k, MeasurementValue v) => values[k] = v;

  Map<String, dynamic> toJson() =>
      values.map((k, v) => MapEntry(k.name, v.toJson()));

  factory Naap.fromJson(Map<String, dynamic> j) => Naap(j.map((k, v) => MapEntry(
      MeasurementKey.values.firstWhere((m) => m.name == k),
      MeasurementValue.fromJson(v as Map<String, dynamic>))));
}
