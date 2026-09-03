/// Per-brand size guidance — the fit library's client-side starting
/// points, derived from published size charts and widely documented fit
/// reputations. Every row is a STARTING POINT (verified: false in the
/// server library) that fit-reports and measured garments refine; the
/// honest label in the UI says so. Deterministic table, no LLM.
library;

import 'models/measurements.dart';
import 'sizing.dart';

enum BrandGender { men, women }

class BrandFit {
  final String brand;
  final BrandGender gender;

  /// EU sizes to ADD to the convention-derived size (+2 = size up: the
  /// house cuts slim; -2 = size down: cuts generous).
  final int euOffset;
  final String note;

  const BrandFit(this.brand, this.gender, this.euOffset, this.note);
}

/// Men: offsets relative to the standard EU suit size (half chest).
/// 2026-09-03: offsets reconciled against harvested published charts
/// (server/app/fit_library.py). Chart law: IT size ≈ body chest ÷ 2 holds
/// for Zegna/Prada/Gucci/Massimo Dutti; Saint Laurent's own chart runs
/// TWO sizes small (their 54 fits the chest a standard 50 fits).
const List<BrandFit> kBrandFitsMen = [
  BrandFit('ZEGNA', BrandGender.men, 0,
      'classic Italian — true to size (chart-verified)'),
  BrandFit('Brioni', BrandGender.men, 0, 'Roman shoulder, generous drop'),
  BrandFit('Kiton', BrandGender.men, 0,
      'Neapolitan soft — true to size (chart-verified)'),
  BrandFit('Brunello Cucinelli', BrandGender.men, 0,
      'relaxed luxury — true to size (chart-verified)'),
  BrandFit('Loro Piana', BrandGender.men, 0, 'true to size'),
  BrandFit('Giorgio Armani', BrandGender.men, -2,
      'soft, roomy cut — many size down (chart-confirmed)'),
  BrandFit('BOSS', BrandGender.men, 0,
      'modern slim — true but trim (chart-verified)'),
  BrandFit('Saint Laurent', BrandGender.men, 4,
      'published chart runs two full sizes small — size up twice'),
  BrandFit('Dior Men', BrandGender.men, 2, 'slim — size up'),
  BrandFit('Gucci', BrandGender.men, 0,
      'per published chart: true to size, slightly roomy'),
  BrandFit('Prada', BrandGender.men, 0,
      'per published chart: true to size (IT = chest ÷ 2)'),
  BrandFit('Massimo Dutti', BrandGender.men, 0,
      'true to size, trim shoulders (chart-verified)'),
  BrandFit('Tom Ford', BrandGender.men, 0, 'structured — true to size'),
  BrandFit('Burberry', BrandGender.men, 0, 'British classic — true'),
  BrandFit('Louis Vuitton', BrandGender.men, 0, 'true to size'),
  BrandFit('Alexander McQueen', BrandGender.men, 2,
      'sharp slim tailoring — size up'),
];

/// Women: offsets relative to the standard EU (DE) ready-to-wear size.
const List<BrandFit> kBrandFitsWomen = [
  BrandFit('Chanel', BrandGender.women, 0, 'true to size, generous bust'),
  BrandFit('Dior', BrandGender.women, 2, 'runs small — size up'),
  BrandFit('Saint Laurent', BrandGender.women, 2,
      'very slim — size up'),
  BrandFit('Valentino', BrandGender.women, 0, 'true to size'),
  BrandFit('Gucci', BrandGender.women, 2, 'slim — size up'),
  BrandFit('Prada', BrandGender.women, 2, 'runs small — size up'),
  BrandFit('Bottega Veneta', BrandGender.women, 0, 'true to size'),
  BrandFit('Loewe', BrandGender.women, 0, 'true to size'),
  BrandFit('Burberry', BrandGender.women, 0, 'true to size'),
  BrandFit('Loro Piana', BrandGender.women, -2,
      'relaxed cut — many size down'),
];

class BrandSizeAdvice {
  final String brand;
  final String size;
  final String note;
  const BrandSizeAdvice(this.brand, this.size, this.note);
}

/// Per-brand recommendations for this body. Men get EU suit sizes with
/// the house offset; women get EU/IT/FR per house on the RTW grid.
List<BrandSizeAdvice> brandAdvice(Naap naap, {required bool female}) {
  if (female) {
    final ls = mapLadiesSizes(naap);
    if (ls == null) return const [];
    return [
      for (final b in kBrandFitsWomen)
        BrandSizeAdvice(
            b.brand,
            'EU ${(ls.eu + b.euOffset).clamp(32, 54)} / '
                'IT ${(ls.it + b.euOffset).clamp(36, 58)} / '
                'FR ${(ls.fr + b.euOffset).clamp(34, 56)}',
            b.note),
    ];
  }
  final sm = mapSuMisura(naap);
  if (sm == null) return const [];
  return [
    for (final b in kBrandFitsMen)
      BrandSizeAdvice(
          b.brand,
          'EU ${(sm.euSize + b.euOffset).clamp(44, 64)} / '
              'US ${(sm.euSize + b.euOffset - 10).clamp(34, 54)}',
          b.note),
  ];
}
