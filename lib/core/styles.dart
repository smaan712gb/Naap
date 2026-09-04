/// Style preferences — the cut decisions a customer makes that are NOT body
/// measurements: neckline, sleeve finish, daman shape, pockets. They ride
/// the parchi in their own section so the tailor gets the full picture.
///
/// Everything is bilingual (EN/UR) like the measurement vocabulary, and
/// deterministic — style never touches the numeric ease path.
library;

enum NecklineStyle { bann, collar, round, vNeck }

enum SleeveStyle { fullCuff, fullPlain, half }

enum DamanStyle { straight, round }

class StyleOption {
  final String english;
  final String urdu;
  const StyleOption(this.english, this.urdu);
}

const Map<NecklineStyle, StyleOption> kNecklineLabels = {
  NecklineStyle.bann: StyleOption('Bann (band collar)', 'بین گلا'),
  NecklineStyle.collar: StyleOption('Shirt collar', 'کالر'),
  NecklineStyle.round: StyleOption('Round (gol gala)', 'گول گلا'),
  NecklineStyle.vNeck: StyleOption('V neck', 'وی گلا'),
};

const Map<SleeveStyle, StyleOption> kSleeveLabels = {
  SleeveStyle.fullCuff: StyleOption('Full sleeve, cuff', 'پوری آستین، کف'),
  SleeveStyle.fullPlain: StyleOption('Full sleeve, plain', 'پوری آستین، سادہ'),
  SleeveStyle.half: StyleOption('Half sleeve', 'آدھی آستین'),
};

const Map<DamanStyle, StyleOption> kDamanLabels = {
  DamanStyle.straight: StyleOption('Straight daman', 'سیدھا دامن'),
  DamanStyle.round: StyleOption('Round daman', 'گول دامن'),
};

/// Kameez/kurta style choices. Neck depth/width are optional refinements —
/// most customers leave them to the tailor; a designer customer can pin
/// them in cm.
class KameezStyle {
  NecklineStyle neckline;
  double? neckDepthCm; // front neck depth below the collarbone notch
  double? neckWidthCm; // width between the neck points
  SleeveStyle sleeve;
  DamanStyle daman;
  bool sidePockets;
  bool chestPocket;

  KameezStyle({
    this.neckline = NecklineStyle.bann,
    this.neckDepthCm,
    this.neckWidthCm,
    this.sleeve = SleeveStyle.fullCuff,
    this.daman = DamanStyle.round,
    this.sidePockets = true,
    this.chestPocket = false,
  });

  Map<String, dynamic> toJson() => {
        'neckline': neckline.name,
        'neckDepthCm': neckDepthCm,
        'neckWidthCm': neckWidthCm,
        'sleeve': sleeve.name,
        'daman': daman.name,
        'sidePockets': sidePockets,
        'chestPocket': chestPocket,
      };

  factory KameezStyle.fromJson(Map<String, dynamic> j) => KameezStyle(
        neckline: NecklineStyle.values.firstWhere(
            (v) => v.name == j['neckline'],
            orElse: () => NecklineStyle.bann),
        neckDepthCm: (j['neckDepthCm'] as num?)?.toDouble(),
        neckWidthCm: (j['neckWidthCm'] as num?)?.toDouble(),
        sleeve: SleeveStyle.values.firstWhere((v) => v.name == j['sleeve'],
            orElse: () => SleeveStyle.fullCuff),
        daman: DamanStyle.values.firstWhere((v) => v.name == j['daman'],
            orElse: () => DamanStyle.round),
        sidePockets: j['sidePockets'] as bool? ?? true,
        chestPocket: j['chestPocket'] as bool? ?? false,
      );

  /// Bilingual summary lines for the parchi's style section.
  List<(String, String)> parchiLines(
      {required bool isInches}) {
    String len(double cm) => isInches
        ? '${(cm / 2.54).toStringAsFixed(1)}"'
        : '${cm.toStringAsFixed(1)} cm';
    final lines = <(String, String)>[
      ('Neckline: ${kNecklineLabels[neckline]!.english}',
          'گلا: ${kNecklineLabels[neckline]!.urdu}'),
      if (neckDepthCm != null)
        ('Front neck depth: ${len(neckDepthCm!)}',
            'گلے کی گہرائی: ${len(neckDepthCm!)}'),
      if (neckWidthCm != null)
        ('Neck width: ${len(neckWidthCm!)}',
            'گلے کی چوڑائی: ${len(neckWidthCm!)}'),
      ('Sleeve: ${kSleeveLabels[sleeve]!.english}',
          'آستین: ${kSleeveLabels[sleeve]!.urdu}'),
      ('Daman: ${kDamanLabels[daman]!.english}',
          'دامن: ${kDamanLabels[daman]!.urdu}'),
      (
        'Pockets: ${sidePockets ? 'side' : 'no side'}'
            '${chestPocket ? ' + chest' : ''}',
        'جیب: ${sidePockets ? 'سائیڈ جیب' : 'بغیر سائیڈ جیب'}'
            '${chestPocket ? ' + سینے کی جیب' : ''}'
      ),
    ];
    return lines;
  }
}

// ---------------------------------------------------------------------------
// European suit style — the order vocabulary for the 60% of overseas
// tailoring that is suits, not shalwar kameez (Imran's split, 2026-09-04).
// Same declarative shape as KameezStyle: bilingual labels, parchi lines,
// tailor-reviewable. Aesthetic words only — never house names.
// ---------------------------------------------------------------------------

enum LapelStyle { notch, peak, shawl }

enum VentStyle { none, single, double_ }

enum PleatStyle { flat, single, double_ }

class SuitStyle {
  LapelStyle lapel;
  bool doubleBreasted;
  int buttons; // 1, 2, 3 (single-breasted); 4/6 handled by doubleBreasted
  VentStyle vents;
  PleatStyle trouserPleats;
  bool trouserCuffs;

  SuitStyle({
    this.lapel = LapelStyle.notch,
    this.doubleBreasted = false,
    this.buttons = 2,
    this.vents = VentStyle.double_,
    this.trouserPleats = PleatStyle.flat,
    this.trouserCuffs = false,
  });

  Map<String, dynamic> toJson() => {
        'lapel': lapel.name,
        'doubleBreasted': doubleBreasted,
        'buttons': buttons,
        'vents': vents.name,
        'trouserPleats': trouserPleats.name,
        'trouserCuffs': trouserCuffs,
      };

  factory SuitStyle.fromJson(Map<String, dynamic> j) => SuitStyle(
        lapel: LapelStyle.values
            .firstWhere((e) => e.name == j['lapel'], orElse: () => LapelStyle.notch),
        doubleBreasted: j['doubleBreasted'] as bool? ?? false,
        buttons: j['buttons'] as int? ?? 2,
        vents: VentStyle.values
            .firstWhere((e) => e.name == j['vents'], orElse: () => VentStyle.double_),
        trouserPleats: PleatStyle.values.firstWhere(
            (e) => e.name == j['trouserPleats'],
            orElse: () => PleatStyle.flat),
        trouserCuffs: j['trouserCuffs'] as bool? ?? false,
      );

  static const lapelEn = {
    LapelStyle.notch: 'Notch lapel',
    LapelStyle.peak: 'Peak lapel',
    LapelStyle.shawl: 'Shawl collar',
  };
  static const ventEn = {
    VentStyle.none: 'No vent',
    VentStyle.single: 'Single vent',
    VentStyle.double_: 'Double vents',
  };
  static const pleatEn = {
    PleatStyle.flat: 'Flat front',
    PleatStyle.single: 'Single pleat',
    PleatStyle.double_: 'Double pleats',
  };

  /// One-line summary for specs and measure-request submissions.
  String get summary =>
      '${doubleBreasted ? 'Double-breasted' : 'Single-breasted'}, '
      '$buttons-button, ${lapelEn[lapel]!.toLowerCase()}, '
      '${ventEn[vents]!.toLowerCase()}; trousers '
      '${pleatEn[trouserPleats]!.toLowerCase()}'
      '${trouserCuffs ? ', cuffed' : ''}';

  List<(String, String)> parchiLines() => [
        ('Jacket',
            '${doubleBreasted ? 'Double' : 'Single'}-breasted · '
                '$buttons button${buttons > 1 ? 's' : ''}'),
        ('Lapel', lapelEn[lapel]!),
        ('Vents', ventEn[vents]!),
        ('Trouser',
            '${pleatEn[trouserPleats]!}${trouserCuffs ? ' · cuffed hem' : ''}'),
      ];
}
