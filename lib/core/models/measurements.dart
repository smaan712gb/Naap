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
  waist, // Kamar
  hip, // Hip / Seat
  sleeveLength, // Baazu
  bicep,
  armhole, // Baghal
  wrist, // Kalai
  kameezLength, // Qameez Lambai
  shalwarLength, // Shalwar Lambai
  inseam,
  thigh, // Raan
  ankleOpening, // Paincha
  hem, // Ghera (kameez bottom sweep)
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
  MeasurementKey.armhole: MeasurementDef(
      key: MeasurementKey.armhole,
      english: 'Armhole',
      urdu: 'بغل',
      tailorTerm: 'Baghal',
      isCircumference: true),
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
