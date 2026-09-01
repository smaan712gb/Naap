import 'package:flutter_test/flutter_test.dart';
import 'package:naap/core/ease.dart';
import 'package:naap/core/fabric.dart';
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
}
