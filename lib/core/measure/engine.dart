/// Naap measurement engine v1 — fully on-device.
///
/// Pipeline per capture (front photo + side photo):
///   1. ML Kit Pose Detection (accurate model) → 33 skeletal landmarks.
///   2. ML Kit Selfie Segmentation → body silhouette mask.
///   3. Height calibration: the user's real height anchors cm-per-pixel.
///   4. Lengths come from landmarks; circumferences come from silhouette
///      widths (front) + depths (side) combined with an elliptical
///      cross-section model (Ramanujan perimeter) and per-region shape
///      factors.
///
/// The raw photos never leave the device and are deleted after analysis.
library;

import 'dart:io';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;

import '../models/measurements.dart';
import '../models/profile.dart';
import 'geometry.dart';

/// Eye height as a fraction of stature (standard anthropometric tables).
/// Used to calibrate cm-per-pixel because ML Kit has no top-of-head landmark.
const double _kEyeHeightRatio = 0.936;

/// Fallback anchors when eyes/heels are occluded (turned head in the side
/// view, hair, long shalwar over the heels): nose height and ankle-bone
/// height as fractions of stature, same anthropometric tables.
const double _kNoseHeightRatio = 0.925;
const double _kAnkleHeightRatio = 0.039;

/// Where key torso rows sit between the shoulder and hip landmark rows.
const double _kChestRowT = 0.30; // shoulder→hip fraction for chest (nipple line)
const double _kWaistRowT = 0.72; // natural waist
const double _kBellyRowT = 0.92; // widest stomach, just above the navel
const double _kSeatRowT = 0.22; // hip landmark → knee fraction for seat fullest point
const double _kCrotchRowT = 0.16; // hip landmark → knee fraction for crotch

/// Elliptical-model shape factors: human cross-sections are not perfect
/// ellipses. Tuned starting points; calibrate against tape measurements.
const double _kChestShape = 0.97;
const double _kWaistShape = 0.99;
const double _kBellyShape = 0.99;
const double _kSeatShape = 0.96;

/// Anti-contamination bounds (first real session read chest AND waist at
/// ~131 cm on a 40R body: hanging arms merge with the torso silhouette in
/// both views). Shoulder landmarks are joints — arms cannot contaminate
/// them — so torso width at a row is capped as a fraction of the shoulder
/// landmark span, and depth as a fraction of that row's width. Generous
/// caps: they only cut obvious arm merges, real bodies stay untouched.
const double _kChestWidthOfShoulder = 0.85;
const double _kWaistWidthOfShoulder = 0.90;
const double _kBellyWidthOfShoulder = 0.95;
const double _kSeatWidthOfShoulder = 0.95;
const double _kChestDepthOfWidth = 0.85;
const double _kWaistDepthOfWidth = 0.95;
const double _kBellyDepthOfWidth = 1.0; // bellies legitimately run deep
const double _kSeatDepthOfWidth = 0.95;

class CaptureIssue {
  final String message;
  final bool blocking;
  const CaptureIssue(this.message, {this.blocking = false});
}

class EngineResult {
  final Naap naap;
  final List<CaptureIssue> issues;
  const EngineResult(this.naap, this.issues);

  bool get hasBlockingIssues => issues.any((i) => i.blocking);
}

class _View {
  final Pose pose;
  final List<double> mask; // row-major confidences
  final int maskW, maskH;
  final int imgW, imgH;

  _View(this.pose, this.mask, this.maskW, this.maskH, this.imgW, this.imgH);

  /// Landmark position scaled into mask pixel space.
  ({double x, double y}) lm(PoseLandmarkType t) {
    final p = pose.landmarks[t]!;
    return (x: p.x * maskW / imgW, y: p.y * maskH / imgH);
  }

  double lmLikelihood(PoseLandmarkType t) =>
      pose.landmarks[t]?.likelihood ?? 0.0;
}

class MeasurementEngine {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.single,
      model: PoseDetectionModel.accurate,
    ),
  );
  final SelfieSegmenter _segmenter = SelfieSegmenter(
    mode: SegmenterMode.single,
    enableRawSizeMask: false,
  );

  Future<void> dispose() async {
    await _poseDetector.close();
    _segmenter.close();
  }

  Future<EngineResult> analyze({
    required String frontImagePath,
    required String sideImagePath,
    required UserProfile profile,
  }) async {
    final issues = <CaptureIssue>[];

    final front = await _analyzeView(frontImagePath, issues, 'front');
    final side = await _analyzeView(sideImagePath, issues, 'side');
    if (front == null || side == null) {
      return EngineResult(Naap.empty(),
          [...issues, const CaptureIssue('Could not detect a full body in one of the photos. Please retake in good light, 2–3 m from the camera.', blocking: true)]);
    }

    final naap = Naap.empty();
    final h = profile.heightCm;
    naap.set(MeasurementKey.height,
        MeasurementValue(h, source: MeasurementSource.manual));

    // ---- Calibration: cm per mask-pixel in each view ----
    final cmPerPxF = _cmPerPx(front, h, issues, 'front');
    final cmPerPxS = _cmPerPx(side, h, issues, 'side');
    if (cmPerPxF == null || cmPerPxS == null) {
      // _cmPerPx already added a specific, actionable issue per view.
      if (!issues.any((i) => i.blocking)) {
        issues.add(const CaptureIssue(
            'Could not calibrate height from the photos — retake with the '
            'whole body in frame.',
            blocking: true));
      }
      return EngineResult(Naap.empty(), issues);
    }

    // ---- Landmark anchors (front view, mask space) ----
    final lSh = front.lm(PoseLandmarkType.leftShoulder);
    final rSh = front.lm(PoseLandmarkType.rightShoulder);
    final lHip = front.lm(PoseLandmarkType.leftHip);
    final rHip = front.lm(PoseLandmarkType.rightHip);
    final lKnee = front.lm(PoseLandmarkType.leftKnee);
    final lAnkle = front.lm(PoseLandmarkType.leftAnkle);
    final rAnkle = front.lm(PoseLandmarkType.rightAnkle);
    final lElbow = front.lm(PoseLandmarkType.leftElbow);
    final lWrist = front.lm(PoseLandmarkType.leftWrist);

    final shoulderY = (lSh.y + rSh.y) / 2;
    final hipY = (lHip.y + rHip.y) / 2;
    final kneeY = lKnee.y;
    final torsoMidX = ((lSh.x + rSh.x) / 2 + (lHip.x + rHip.x) / 2) / 2;

    // ---- Lengths (landmark-based, high confidence) ----
    // Shoulder landmarks sit at the joints; real shoulder points (acromion)
    // are slightly outside, hence the 1.06 factor.
    final shoulderCm =
        dist(lSh.x, lSh.y, rSh.x, rSh.y) * cmPerPxF * 1.06;
    naap.set(MeasurementKey.shoulder,
        MeasurementValue(shoulderCm, source: MeasurementSource.landmarks, confidence: 0.9));

    final sleeveCm = (dist(lSh.x, lSh.y, lElbow.x, lElbow.y) +
            dist(lElbow.x, lElbow.y, lWrist.x, lWrist.y)) *
        cmPerPxF;
    naap.set(MeasurementKey.sleeveLength,
        MeasurementValue(sleeveCm, source: MeasurementSource.landmarks, confidence: 0.85));

    final ankleY = (lAnkle.y + rAnkle.y) / 2;
    final crotchY = hipY + _kCrotchRowT * (kneeY - hipY);
    final inseamCm = (ankleY - crotchY) * cmPerPxF;
    naap.set(MeasurementKey.inseam,
        MeasurementValue(inseamCm, source: MeasurementSource.landmarks, confidence: 0.8));

    // Outseam-style shalwar/trouser length: natural waist to ankle bone.
    final waistY = shoulderY + _kWaistRowT * (hipY - shoulderY);
    final shalwarCm = (ankleY - waistY) * cmPerPxF + 2.0; // +2 to shoe top
    naap.set(MeasurementKey.shalwarLength,
        MeasurementValue(shalwarCm, source: MeasurementSource.landmarks, confidence: 0.8));

    // Kameez length default: shoulder to just above the knee (style default,
    // freely editable on the review screen).
    final kameezCm = (kneeY - shoulderY) * cmPerPxF * 0.93;
    naap.set(MeasurementKey.kameezLength,
        MeasurementValue(kameezCm, source: MeasurementSource.landmarks, confidence: 0.7));

    // ---- Circumferences (silhouette widths + depths, elliptical model) ----
    // Arms merged with the torso silhouette are the dominant real-world
    // failure (see the _k*Of* constants above). Widths are capped against
    // the shoulder-landmark span, depths against the row's width; a capped
    // row is flagged low-confidence and reported as a retake hint.
    final shoulderSpanCm = dist(lSh.x, lSh.y, rSh.x, rSh.y) * cmPerPxF;
    var contaminated = false;
    void circumference(MeasurementKey key, double rowYF, double rowYS,
        double shapeFactor, double conf, double widthCapOfShoulder,
        double depthCapOfWidth) {
      final wRun = runAtRow(front.mask, front.maskW, front.maskH,
          rowYF.round(), torsoMidX.round());
      final sMid = _sideTorsoMidX(side);
      final dRun = runAtRow(
          side.mask, side.maskW, side.maskH, rowYS.round(), sMid.round());
      if (wRun == null || dRun == null) return;
      var widthCm = wRun.widthPx * cmPerPxF;
      var depthCm = dRun.widthPx * cmPerPxS;
      var rowConf = conf;
      final widthCap = shoulderSpanCm * widthCapOfShoulder;
      if (widthCm > widthCap) {
        widthCm = widthCap;
        rowConf = 0.45;
        contaminated = true;
      }
      final depthCap = widthCm * depthCapOfWidth;
      if (depthCm > depthCap) {
        depthCm = depthCap;
        rowConf = 0.45;
        contaminated = true;
      }
      final c = ramanujan(widthCm / 2, depthCm / 2) * shapeFactor;
      naap.set(key,
          MeasurementValue(c, source: MeasurementSource.silhouette, confidence: rowConf));
    }

    // Corresponding rows in the side view (its own landmark frame).
    final sShY = (side.lm(PoseLandmarkType.leftShoulder).y +
            side.lm(PoseLandmarkType.rightShoulder).y) /
        2;
    final sHipY = (side.lm(PoseLandmarkType.leftHip).y +
            side.lm(PoseLandmarkType.rightHip).y) /
        2;
    final sKneeY = side.lm(PoseLandmarkType.leftKnee).y;

    circumference(
        MeasurementKey.chest,
        shoulderY + _kChestRowT * (hipY - shoulderY),
        sShY + _kChestRowT * (sHipY - sShY),
        _kChestShape,
        0.7,
        _kChestWidthOfShoulder,
        _kChestDepthOfWidth);
    circumference(
        MeasurementKey.waist,
        waistY,
        sShY + _kWaistRowT * (sHipY - sShY),
        _kWaistShape,
        0.7,
        _kWaistWidthOfShoulder,
        _kWaistDepthOfWidth);
    circumference(
        MeasurementKey.belly,
        shoulderY + _kBellyRowT * (hipY - shoulderY),
        sShY + _kBellyRowT * (sHipY - sShY),
        _kBellyShape,
        0.6,
        _kBellyWidthOfShoulder,
        _kBellyDepthOfWidth);
    circumference(
        MeasurementKey.hip,
        hipY + _kSeatRowT * (kneeY - hipY),
        sHipY + _kSeatRowT * (sKneeY - sHipY),
        _kSeatShape,
        0.65,
        _kSeatWidthOfShoulder,
        _kSeatDepthOfWidth);
    if (contaminated) {
      issues.add(const CaptureIssue(
          'Arms may have blended into the body outline — the affected '
          'girths were bounded and marked for checking. For best accuracy '
          'retake with arms lifted ~30° in the front photo and hands at '
          'your sides in the side photo.'));
    }

    // Thigh: front width at upper thigh × circular-ish model with side depth.
    final thighYF = hipY + 0.35 * (kneeY - hipY);
    // Use half the hip-run width as a proxy for a single thigh in front view.
    final thighRun = runAtRow(front.mask, front.maskW, front.maskH,
        thighYF.round(), lKnee.x.round());
    if (thighRun != null) {
      final tw = thighRun.widthPx * cmPerPxF;
      // Single-leg run when legs are apart; assume near-circular section.
      naap.set(
          MeasurementKey.thigh,
          MeasurementValue(tw * 3.1416 * 0.5 * 0.95,
              source: MeasurementSource.silhouette, confidence: 0.5));
    }

    // ---- Regression fallbacks (low confidence, always editable) ----
    final weight = profile.weightKg;
    if (naap[MeasurementKey.neck] == null) {
      // Neck circumference scales with stature and BMI; simple linear model.
      // Coefficients raised 2026-09-02 from the first calibration data
      // point: a 16-17 collar tester (body neck ~39-41 cm) read 36.6 cm at
      // the old 0.20 male coefficient.
      final bmi = weight != null ? weight / ((h / 100) * (h / 100)) : 23.0;
      final neck = (profile.bodyType == BodyType.male ? 0.225 : 0.205) * h +
          (bmi - 23.0) * 0.45;
      naap.set(MeasurementKey.neck,
          MeasurementValue(neck, source: MeasurementSource.regression, confidence: 0.4));
    }
    naap.set(
        MeasurementKey.wrist,
        MeasurementValue(h * 0.098,
            source: MeasurementSource.regression, confidence: 0.4));
    naap.set(
        MeasurementKey.bicep,
        MeasurementValue(
            (naap[MeasurementKey.chest]?.cm ?? h * 0.55) * 0.32,
            source: MeasurementSource.regression,
            confidence: 0.4));
    // Armscye circumference tracks chest size closely (~0.45x).
    naap.set(
        MeasurementKey.armhole,
        MeasurementValue(
            (naap[MeasurementKey.chest]?.cm ?? h * 0.55) * 0.45,
            source: MeasurementSource.regression,
            confidence: 0.4));
    // Trouser waistband sits at the high hip, between natural waist and seat.
    final waistCm = naap[MeasurementKey.waist]?.cm;
    final hipCm = naap[MeasurementKey.hip]?.cm;
    if (waistCm != null && hipCm != null) {
      naap.set(
          MeasurementKey.trouserWaist,
          MeasurementValue(waistCm + 0.4 * (hipCm - waistCm),
              source: MeasurementSource.regression, confidence: 0.45));
    }
    // European drafting estimates — starting points a tailor refines.
    // Jacket length: nape to thumb knuckle ≈ 0.44 of stature.
    naap.set(
        MeasurementKey.jacketLength,
        MeasurementValue(h * 0.44,
            source: MeasurementSource.regression, confidence: 0.4));
    final chestCm = naap[MeasurementKey.chest]?.cm ?? h * 0.55;
    naap.set(
        MeasurementKey.frontChest,
        MeasurementValue(chestCm * 0.36,
            source: MeasurementSource.regression, confidence: 0.35));
    naap.set(
        MeasurementKey.backWidth,
        MeasurementValue(chestCm * 0.43,
            source: MeasurementSource.regression, confidence: 0.35));
    naap.set(
        MeasurementKey.ankleOpening,
        MeasurementValue(h * 0.16,
            source: MeasurementSource.regression, confidence: 0.4));
    naap.set(
        MeasurementKey.hem,
        MeasurementValue((naap[MeasurementKey.hip]?.cm ?? h * 0.6) + 10,
            source: MeasurementSource.regression, confidence: 0.4));

    return EngineResult(naap, issues);
  }

  /// cm-per-pixel from eye row and heel row against known stature.
  /// Height calibration. Top anchor: whichever eye ML Kit is most sure of,
  /// falling back to the nose (in a side photo the far eye is hidden, which
  /// used to hard-fail every capture). Bottom anchor: either heel, falling
  /// back to either ankle. Adds a specific issue naming the view and the
  /// missing end when it fails.
  double? _cmPerPx(_View v, double heightCm, List<CaptureIssue> issues,
      String label) {
    ({double x, double y})? top;
    var topRatio = _kEyeHeightRatio;
    final eyeType = [PoseLandmarkType.leftEye, PoseLandmarkType.rightEye]
        .where((t) => v.lmLikelihood(t) > 0.3)
        .fold<PoseLandmarkType?>(null,
            (best, t) => best == null || v.lmLikelihood(t) > v.lmLikelihood(best) ? t : best);
    if (eyeType != null) {
      top = v.lm(eyeType);
    } else if (v.lmLikelihood(PoseLandmarkType.nose) > 0.3) {
      top = v.lm(PoseLandmarkType.nose);
      topRatio = _kNoseHeightRatio;
    }

    ({double x, double y})? bottom;
    var bottomRatio = 0.0;
    final heels = [PoseLandmarkType.leftHeel, PoseLandmarkType.rightHeel]
        .where((t) => v.lmLikelihood(t) > 0.3)
        .map(v.lm)
        .toList();
    if (heels.isNotEmpty) {
      bottom = (
        x: heels.map((p) => p.x).reduce((a, b) => a + b) / heels.length,
        y: heels.map((p) => p.y).reduce((a, b) => a + b) / heels.length,
      );
    } else {
      final ankles = [PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle]
          .where((t) => v.lmLikelihood(t) > 0.3)
          .map(v.lm)
          .toList();
      if (ankles.isNotEmpty) {
        bottom = (
          x: ankles.map((p) => p.x).reduce((a, b) => a + b) / ankles.length,
          y: ankles.map((p) => p.y).reduce((a, b) => a + b) / ankles.length,
        );
        bottomRatio = _kAnkleHeightRatio;
      }
    }

    if (top == null) {
      issues.add(CaptureIssue(
          'Could not see the face in the $label photo — face the camera '
          '(front) or look straight ahead (side), hair away from the face.',
          blocking: true));
      return null;
    }
    if (bottom == null) {
      issues.add(CaptureIssue(
          'Could not see the feet in the $label photo — step back so the '
          'whole body, head to bare heels, is inside the outline.',
          blocking: true));
      return null;
    }
    final px = bottom.y - top.y;
    if (px <= 0) {
      issues.add(CaptureIssue(
          'The $label photo does not show a standing person — set the phone '
          'upright at waist height, 2–3 m away, and stand facing it.',
          blocking: true));
      return null;
    }
    return (heightCm * (topRatio - bottomRatio)) / px;
  }

  double _sideTorsoMidX(_View v) {
    final sh = v.lm(PoseLandmarkType.leftShoulder);
    final hip = v.lm(PoseLandmarkType.leftHip);
    return (sh.x + hip.x) / 2;
  }

  Future<_View?> _analyzeView(
      String path, List<CaptureIssue> issues, String label) async {
    // iPhones store photos sideways with an EXIF rotation flag, so the
    // landmark coordinates and the decoded pixel grid can disagree about
    // which way is up — every real iOS capture then failed as "not a
    // standing person". Bake the rotation into the pixels first so the
    // detectors, the mask, and the dimensions all see the same upright
    // image on every platform.
    final decoded = await img.decodeImageFile(path);
    if (decoded == null) {
      issues.add(CaptureIssue('Could not read the $label photo.', blocking: true));
      return null;
    }
    final upright = img.bakeOrientation(decoded);
    final normFile = File('$path.upright.jpg');
    await normFile.writeAsBytes(img.encodeJpg(upright, quality: 92));
    try {
      final input = InputImage.fromFilePath(normFile.path);
      final poses = await _poseDetector.processImage(input);
      if (poses.isEmpty) {
        issues.add(CaptureIssue('No person detected in the $label photo.',
            blocking: true));
        return null;
      }
      final mask = await _segmenter.processImage(input);
      if (mask == null) {
        issues.add(CaptureIssue(
            'Could not separate the body from the background in the $label photo.',
            blocking: true));
        return null;
      }
      return _View(poses.first, mask.confidences, mask.width, mask.height,
          upright.width, upright.height);
    } finally {
      // Privacy contract: the normalized copy is a capture photo too.
      if (await normFile.exists()) await normFile.delete();
    }
  }
}

/// Deletes capture photos after analysis — part of the privacy contract.
Future<void> shredCaptures(Iterable<String> paths) async {
  for (final p in paths) {
    try {
      final f = File(p);
      if (await f.exists()) await f.delete();
    } catch (_) {/* best effort */}
  }
}
