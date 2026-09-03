import 'package:flutter_test/flutter_test.dart';
import 'package:naap/core/ease.dart';
import 'package:naap/core/fabric.dart';
import 'package:naap/core/learning.dart';
import 'package:naap/core/brand_fits.dart';
import 'package:naap/core/measure/posture.dart';
import 'package:naap/core/silhouettes.dart';
import 'package:naap/core/measure/geometry.dart';
import 'package:naap/core/models/measurements.dart';
import 'package:naap/core/sizing.dart';

void main() {
  group('geometry', () {
    test('ramanujan matches circle perimeter', () {
      expect(ramanujan(10, 10), closeTo(2 * 3.14159265 * 10, 0.01));
    });

    test('ramanujan on torso-like ellipse', () {
      // a=17cm half-width, b=11cm half-depth → chest ~ 89cm ballpark
      final c = ramanujan(17, 11);
      expect(c, inInclusiveRange(85, 95));
    });

    test('runAtRow finds torso run and ignores arms', () {
      // 20x5 mask: row 2 has arm run [1..3], gap, torso [8..13], gap, arm [16..18]
      const w = 20, h = 5;
      final mask = List<double>.filled(w * h, 0.0);
      for (final x in [1, 2, 3, 8, 9, 10, 11, 12, 13, 16, 17, 18]) {
        mask[2 * w + x] = 1.0;
      }
      final run = runAtRow(mask, w, h, 2, 10);
      expect(run, isNotNull);
      expect(run!.left, 8);
      expect(run.right, 13);
      expect(run.widthPx, 6);
    });

    test('runAtRow nudges anchor near edge', () {
      const w = 20, h = 3;
      final mask = List<double>.filled(w * h, 0.0);
      for (var x = 5; x <= 10; x++) {
        mask[1 * w + x] = 1.0;
      }
      final run = runAtRow(mask, w, h, 1, 12); // anchor just outside run
      expect(run, isNotNull);
      expect(run!.left, 5);
    });

    test('runAtRow returns null when anchor far from body', () {
      const w = 20, h = 3;
      final mask = List<double>.filled(w * h, 0.0);
      mask[w + 2] = 1.0;
      expect(runAtRow(mask, w, h, 1, 15), isNull);
    });
  });

  group('ease engine', () {
    Naap sampleNaap() {
      final n = Naap.empty();
      n.set(MeasurementKey.chest,
          const MeasurementValue(96, source: MeasurementSource.silhouette));
      n.set(MeasurementKey.waist,
          const MeasurementValue(84, source: MeasurementSource.silhouette));
      n.set(MeasurementKey.kameezLength,
          const MeasurementValue(100, source: MeasurementSource.landmarks));
      n.set(MeasurementKey.shoulder,
          const MeasurementValue(45, source: MeasurementSource.landmarks));
      return n;
    }

    test('regular shalwar kameez adds ~10cm chest asan', () {
      final lines = EaseEngine.buildParchi(
          sampleNaap(), GarmentType.shalwarKameez, FitPreference.regular);
      final chest =
          lines.firstWhere((l) => l.def.key == MeasurementKey.chest);
      expect(chest.stitchCm - chest.bodyCm, closeTo(10.0, 0.001));
    });

    test('fitted reduces ease, loose increases it', () {
      final fitted = EaseEngine.buildParchi(
          sampleNaap(), GarmentType.shalwarKameez, FitPreference.fitted);
      final loose = EaseEngine.buildParchi(
          sampleNaap(), GarmentType.shalwarKameez, FitPreference.loose);
      final fc = fitted.firstWhere((l) => l.def.key == MeasurementKey.chest);
      final lc = loose.firstWhere((l) => l.def.key == MeasurementKey.chest);
      expect(fc.stitchCm, lessThan(lc.stitchCm));
    });

    test('skips measurements missing from naap', () {
      final lines = EaseEngine.buildParchi(
          sampleNaap(), GarmentType.suitTwoPiece, FitPreference.regular);
      expect(lines.any((l) => l.def.key == MeasurementKey.inseam), isFalse);
    });

    test('chaak is a third of kameez length', () {
      expect(EaseEngine.chaakCm(99), closeTo(33, 0.001));
    });

    test('rigid raw silk adds extra ease to circumferences', () {
      final base = EaseEngine.buildParchi(
          sampleNaap(), GarmentType.shalwarKameez, FitPreference.regular);
      final silk = EaseEngine.buildParchi(
          sampleNaap(), GarmentType.shalwarKameez, FitPreference.regular,
          fabric: FabricType.rawSilk);
      final baseChest =
          base.firstWhere((l) => l.def.key == MeasurementKey.chest);
      final silkChest =
          silk.firstWhere((l) => l.def.key == MeasurementKey.chest);
      expect(silkChest.stitchCm - baseChest.stitchCm, closeTo(1.3, 0.001));
    });

    test('stretch knit reduces ease', () {
      final base = EaseEngine.buildParchi(
          sampleNaap(), GarmentType.shalwarKameez, FitPreference.regular);
      final knit = EaseEngine.buildParchi(
          sampleNaap(), GarmentType.shalwarKameez, FitPreference.regular,
          fabric: FabricType.stretchKnit);
      final baseChest =
          base.firstWhere((l) => l.def.key == MeasurementKey.chest);
      final knitChest =
          knit.firstWhere((l) => l.def.key == MeasurementKey.chest);
      expect(knitChest.stitchCm, lessThan(baseChest.stitchCm));
    });

    test('fabric never touches lengths or style numbers', () {
      final base = EaseEngine.buildParchi(
          sampleNaap(), GarmentType.shalwarKameez, FitPreference.regular);
      final silk = EaseEngine.buildParchi(
          sampleNaap(), GarmentType.shalwarKameez, FitPreference.regular,
          fabric: FabricType.rawSilk);
      final baseLen =
          base.firstWhere((l) => l.def.key == MeasurementKey.kameezLength);
      final silkLen =
          silk.firstWhere((l) => l.def.key == MeasurementKey.kameezLength);
      expect(silkLen.stitchCm, baseLen.stitchCm);
    });

    test('lawn baseline fabric changes nothing', () {
      final base = EaseEngine.buildParchi(
          sampleNaap(), GarmentType.shalwarKameez, FitPreference.regular);
      final lawn = EaseEngine.buildParchi(
          sampleNaap(), GarmentType.shalwarKameez, FitPreference.regular,
          fabric: FabricType.lawn);
      for (var i = 0; i < base.length; i++) {
        expect(lawn[i].stitchCm, base[i].stitchCm);
      }
    });
  });

  group('su misura sizing', () {
    Naap bodyNaap(double chest, double waist, double hip) {
      final n = Naap.empty();
      n.set(MeasurementKey.chest,
          MeasurementValue(chest, source: MeasurementSource.silhouette));
      n.set(MeasurementKey.waist,
          MeasurementValue(waist, source: MeasurementSource.silhouette));
      n.set(MeasurementKey.hip,
          MeasurementValue(hip, source: MeasurementSource.silhouette));
      return n;
    }

    test('regular 100cm chest maps to EU 50 drop 6', () {
      final s = mapSuMisura(bodyNaap(100, 88, 102))!;
      expect(s.euSize, 50);
      expect(s.drop, 6);
      expect(s.chestDeltaCm, 0.0);
    });

    test('athletic build gets a note', () {
      final s = mapSuMisura(bodyNaap(104, 86, 100))!;
      expect(s.drop, greaterThanOrEqualTo(8));
      expect(s.notes, isNotEmpty);
    });

    test('missing measurements return null', () {
      expect(mapSuMisura(Naap.empty()), isNull);
    });

    test('out-of-range chest returns null', () {
      expect(mapSuMisura(bodyNaap(40, 40, 40)), isNull);
    });
  });

  group('posture profiling', () {
    test('slope angle and classification bands', () {
      // Neck at (100,50); shoulder 40px out, 10px down → ~14° = square.
      final sq = shoulderSlopeDeg(
          neckX: 100, neckY: 50, shoulderX: 140, shoulderY: 60);
      expect(sq, closeTo(14.0, 0.5));
      expect(classifySlope(sq), 'square');
      // 40 out, 16 down → ~21.8° = regular; 40 out, 22 down → ~28.8° sloping.
      expect(
          classifySlope(shoulderSlopeDeg(
              neckX: 100, neckY: 50, shoulderX: 140, shoulderY: 66)),
          'regular');
      expect(
          classifySlope(shoulderSlopeDeg(
              neckX: 100, neckY: 50, shoulderX: 60, shoulderY: 72)),
          'sloping');
    });

    test('balance classification', () {
      expect(classifyBalance(0), 'erect');
      expect(classifyBalance(6.0), 'forward-leaning');
      expect(classifyBalance(-5.0), 'reclined');
    });

    test('roundtrips through json with tailor summary', () {
      const p = PostureProfile(
          leftSlopeDeg: 24,
          rightSlopeDeg: 18,
          slopeClass: 'regular',
          headForwardCm: 6.2,
          balanceClass: 'erect');
      final back = PostureProfile.fromJson(p.toJson());
      expect(back.slopeClass, 'regular');
      expect(back.tailorSummary, contains('uneven'));
      expect(back.tailorSummary, contains('forward 6 cm'));
    });
  });

  group('brand fits', () {
    test('slim houses size up for men', () {
      final naap = Naap.empty()
        ..set(MeasurementKey.chest, const MeasurementValue(100))
        ..set(MeasurementKey.waist, const MeasurementValue(88))
        ..set(MeasurementKey.hip, const MeasurementValue(102));
      final advice = brandAdvice(naap, female: false);
      final zegna = advice.firstWhere((a) => a.brand == 'ZEGNA');
      final slp = advice.firstWhere((a) => a.brand == 'Saint Laurent');
      expect(zegna.size, contains('EU 50'));
      expect(slp.size, contains('EU 52'));
    });

    test('women get tri-convention sizes per house', () {
      final naap = Naap.empty()
        ..set(MeasurementKey.chest, const MeasurementValue(84))
        ..set(MeasurementKey.waist, const MeasurementValue(66))
        ..set(MeasurementKey.hip, const MeasurementValue(92));
      final advice = brandAdvice(naap, female: true);
      final chanel = advice.firstWhere((a) => a.brand == 'Chanel');
      expect(chanel.size, contains('EU 36'));
      expect(chanel.size, contains('FR 38'));
    });
  });

  group('ladies sizing', () {
    Naap lady(double bust, double waist, double hip) => Naap.empty()
      ..set(MeasurementKey.chest, MeasurementValue(bust))
      ..set(MeasurementKey.waist, MeasurementValue(waist))
      ..set(MeasurementKey.hip, MeasurementValue(hip));

    test('EU 36 bust maps across conventions', () {
      final ls = mapLadiesSizes(lady(84, 66, 92))!;
      expect(ls.eu, 36);
      expect(ls.it, 40);
      expect(ls.fr, 38);
      expect(ls.uk, 8);
      expect(ls.us, 6);
    });

    test('pear figure gets a bottoms note', () {
      final ls = mapLadiesSizes(lady(84, 70, 104))!;
      expect(ls.notes.any((n) => n.contains('Hips size EU')), isTrue);
    });

    test('out-of-range bust returns null', () {
      expect(mapLadiesSizes(lady(50, 40, 60)), isNull);
    });
  });

  group('serialization', () {
    test('naap roundtrips through json', () {
      final n = Naap.empty();
      n.set(MeasurementKey.chest,
          const MeasurementValue(96.5, source: MeasurementSource.silhouette, confidence: 0.7));
      final back = Naap.fromJson(n.toJson());
      expect(back[MeasurementKey.chest]!.cm, 96.5);
      expect(back[MeasurementKey.chest]!.source, MeasurementSource.silhouette);
      expect(back[MeasurementKey.chest]!.confidence, 0.7);
    });
  });

  group('darzi heuristics', () {
    test('trouser paicha is floored at calf minus margin', () {
      final naap = Naap.empty()
        ..set(MeasurementKey.ankleOpening, const MeasurementValue(28.0))
        ..set(MeasurementKey.calf, const MeasurementValue(37.0));
      final lines = EaseEngine.buildParchi(
          naap, GarmentType.trousersShirt, FitPreference.fitted);
      final paicha = lines
          .firstWhere((l) => l.def.key == MeasurementKey.ankleOpening);
      expect(paicha.stitchCm, 34.5); // 37 calf - 2.5 margin
    });

    test('shalwar paicha stays a pure style number', () {
      final naap = Naap.empty()
        ..set(MeasurementKey.ankleOpening, const MeasurementValue(28.0))
        ..set(MeasurementKey.calf, const MeasurementValue(37.0));
      final lines = EaseEngine.buildParchi(
          naap, GarmentType.shalwarKameez, FitPreference.regular);
      final paicha = lines
          .firstWhere((l) => l.def.key == MeasurementKey.ankleOpening);
      expect(paicha.stitchCm, 28.0);
    });
  });

  group('silhouette engine', () {
    Naap body() => Naap.empty()
      ..set(MeasurementKey.knee, const MeasurementValue(38.0))
      ..set(MeasurementKey.calf, const MeasurementValue(37.0))
      ..set(MeasurementKey.ankleOpening, const MeasurementValue(30.0))
      ..set(MeasurementKey.shalwarLength, const MeasurementValue(94.0));

    double stitchOf(List<ParchiLine> lines, MeasurementKey k) =>
        lines.firstWhere((l) => l.def.key == k).stitchCm;

    test('wide flare opens the hem and pools length', () {
      final lines = EaseEngine.buildParchi(
          body(), GarmentType.trousersShirt, FitPreference.regular,
          silhouette: SilhouetteProfile.wideFlared);
      expect(stitchOf(lines, MeasurementKey.knee), 48.0); // 38 + 10
      expect(stitchOf(lines, MeasurementKey.ankleOpening), 51.0);
      expect(stitchOf(lines, MeasurementKey.shalwarLength), 96.5);
    });

    test('skinny is defined by the calf feasibility floor', () {
      final lines = EaseEngine.buildParchi(
          body(), GarmentType.trousersShirt, FitPreference.regular,
          silhouette: SilhouetteProfile.skinny);
      expect(stitchOf(lines, MeasurementKey.ankleOpening),
          closeTo(38.3, 0.001)); // calf 37 + 1.3 — never narrower
      expect(stitchOf(lines, MeasurementKey.shalwarLength), 91.5);
    });

    test('silhouette never touches a shalwar kameez', () {
      final naap = body()
        ..set(MeasurementKey.chest, const MeasurementValue(100.0));
      final lines = EaseEngine.buildParchi(
          naap, GarmentType.shalwarKameez, FitPreference.regular,
          silhouette: SilhouetteProfile.skinny);
      expect(stitchOf(lines, MeasurementKey.ankleOpening), 30.0);
    });

    test('body column is silhouette-independent (immutable truth)', () {
      final lines = EaseEngine.buildParchi(
          body(), GarmentType.trousersShirt, FitPreference.regular,
          silhouette: SilhouetteProfile.wideFlared);
      final knee =
          lines.firstWhere((l) => l.def.key == MeasurementKey.knee);
      expect(knee.bodyCm, 38.0);
    });
  });

  group('per-user learning', () {
    test('learns a correction and applies it to the next AI value', () {
      final cal = PersonalCalibration();
      cal.learn(MeasurementKey.chest, aiCm: 96.0, manualCm: 100.0);
      final naap = Naap.empty()
        ..set(
            MeasurementKey.chest,
            const MeasurementValue(95.0,
                source: MeasurementSource.silhouette, confidence: 0.7));
      cal.apply(naap);
      expect(naap[MeasurementKey.chest]!.cm, closeTo(99.0, 0.001));
      expect(naap[MeasurementKey.chest]!.confidence, closeTo(0.85, 0.001));
    });

    test('never touches manual values', () {
      final cal = PersonalCalibration();
      cal.learn(MeasurementKey.waist, aiCm: 90, manualCm: 86);
      final naap = Naap.empty()
        ..set(MeasurementKey.waist, const MeasurementValue(88.0));
      cal.apply(naap);
      expect(naap[MeasurementKey.waist]!.cm, 88.0);
    });

    test('a wild edit is clamped so it cannot poison future captures', () {
      final cal = PersonalCalibration();
      cal.learn(MeasurementKey.hip, aiCm: 100, manualCm: 160); // typo edit
      expect(cal.deltas[MeasurementKey.hip], PersonalCalibration.maxDeltaCm);
    });

    test('repeated corrections converge as an EWMA', () {
      final cal = PersonalCalibration();
      cal.learn(MeasurementKey.neck, aiCm: 38, manualCm: 40); // +2
      cal.learn(MeasurementKey.neck, aiCm: 38, manualCm: 42); // +4
      expect(cal.deltas[MeasurementKey.neck], closeTo(3.0, 0.001));
    });

    test('roundtrips through json', () {
      final cal = PersonalCalibration();
      cal.learn(MeasurementKey.chest, aiCm: 96, manualCm: 99);
      final back =
          PersonalCalibration.fromJsonString(cal.toJsonString());
      expect(back.deltas[MeasurementKey.chest], closeTo(3.0, 0.001));
    });
  });
}
