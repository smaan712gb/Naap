/// Live capture coaching — the v1.5 auto-capture brain.
///
/// Runs ML Kit pose detection (stream mode, base model) on the live camera
/// feed and turns landmarks into deterministic framing verdicts: is a person
/// visible, whole body in frame, right size in frame, hands where the
/// measurement engine needs them, and holding still. When a pose has been
/// GOOD and stable for [holdDuration], [CoachStatus.capture] fires and the
/// screen takes the photo itself — no timer, no retake roulette.
///
/// All frames stay on-device and are never stored; only the most recent
/// landmark positions are kept for the stability check. Same privacy
/// contract as the still-photo engine.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum CoachStatus {
  noPerson,
  headCut,
  feetCut,
  tooSmall,
  tooBig,
  handsInFront,
  faceCamera, // front stage but the body is angled away
  turnSide, // side stage but the body still faces the camera
  hold, // good pose — hold still, countdown running
  capture, // stable long enough: take the photo NOW
}

class CoachResult {
  final CoachStatus status;
  final String en;
  final String ur;

  /// 0..1 progress of the hold-still window (drives the progress ring).
  final double holdProgress;

  const CoachResult(this.status, this.en, this.ur, {this.holdProgress = 0});
}

class LiveCoach {
  LiveCoach({this.holdDuration = const Duration(milliseconds: 1200)});

  final Duration holdDuration;

  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base, // fast enough for live frames
    ),
  );

  bool _busy = false;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  ({double x, double y})? _lastAnchor;
  DateTime? _stableSince;
  DateTime _stageEnteredAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Call on every stage change (front→side, retakes). Clears the stability
  /// anchor so a hold from the previous stage can never carry over — the
  /// double-fire that shot the "side" photo while the user still faced the
  /// camera (field regression, 2026-09-03).
  void resetStage() {
    _stableSince = null;
    _lastAnchor = null;
    _stageEnteredAt = DateTime.now();
  }

  /// Feed one camera frame. Returns null when throttled/busy.
  Future<CoachResult?> process(CameraImage image, CameraDescription camera,
      {required bool sideView}) async {
    final now = DateTime.now();
    if (_busy || now.difference(_lastFrame).inMilliseconds < 180) return null;
    _busy = true;
    _lastFrame = now;
    try {
      final input = _toInputImage(image, camera);
      if (input == null) return null;
      final poses = await _detector.processImage(input);

      final rotation = camera.sensorOrientation;
      final logicalH = (rotation == 90 || rotation == 270)
          ? image.width.toDouble()
          : image.height.toDouble();
      final logicalW = (rotation == 90 || rotation == 270)
          ? image.height.toDouble()
          : image.width.toDouble();

      return _judge(poses, logicalW, logicalH, sideView: sideView);
    } catch (_) {
      return null; // a bad frame is just skipped
    } finally {
      _busy = false;
    }
  }

  CoachResult _judge(List<Pose> poses, double w, double h,
      {required bool sideView}) {
    CoachResult reset(CoachStatus st, String en, String ur) {
      _stableSince = null;
      _lastAnchor = null;
      return CoachResult(st, en, ur);
    }

    if (poses.isEmpty) {
      return reset(CoachStatus.noPerson, 'Stand in front of the camera',
          'کیمرے کے سامنے کھڑے ہوں');
    }
    final pose = poses.first;

    double like(PoseLandmarkType t) => pose.landmarks[t]?.likelihood ?? 0;
    PoseLandmark? lm(PoseLandmarkType t) => pose.landmarks[t];

    // Top anchor: best eye, else nose (same tolerance as the engine).
    final top = [
      PoseLandmarkType.leftEye,
      PoseLandmarkType.rightEye,
      PoseLandmarkType.nose
    ].where((t) => like(t) > 0.3).map(lm).whereType<PoseLandmark>().fold<
        PoseLandmark?>(null, (b, p) => b == null || p.y < b.y ? p : b);
    if (top == null || top.y < h * 0.03) {
      return reset(CoachStatus.headCut, 'Step back — head is cut off',
          'پیچھے ہٹیں — سر کٹ رہا ہے');
    }

    // Bottom anchor: heels, else ankles.
    final bottoms = [
      PoseLandmarkType.leftHeel,
      PoseLandmarkType.rightHeel,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle
    ].where((t) => like(t) > 0.3).map(lm).whereType<PoseLandmark>().toList();
    if (bottoms.isEmpty) {
      return reset(CoachStatus.feetCut, 'Step back — feet not visible',
          'پیچھے ہٹیں — پاؤں نظر نہیں آ رہے');
    }
    final bottomY =
        bottoms.map((p) => p.y).reduce(math.max);
    if (bottomY > h * 0.985) {
      return reset(CoachStatus.feetCut, 'Step back — feet are cut off',
          'پیچھے ہٹیں — پاؤں کٹ رہے ہیں');
    }

    final span = (bottomY - top.y) / h;
    if (span < 0.45) {
      return reset(CoachStatus.tooSmall, 'Come closer to the camera',
          'کیمرے کے قریب آئیں');
    }
    if (span > 0.94) {
      return reset(CoachStatus.tooBig, 'Step back a little', 'تھوڑا پیچھے ہٹیں');
    }

    // Facing-angle gate: the shoulder x-span (normalized by body height)
    // says which way the body points — wide = facing the camera, collapsed
    // = true side-on. The front photo requires a square stance; the side
    // photo fires only once the user has ACTUALLY turned, so the coach
    // watches the turn happen instead of trusting choreography.
    final lShoulder = lm(PoseLandmarkType.leftShoulder);
    final rShoulder = lm(PoseLandmarkType.rightShoulder);
    if (lShoulder != null && rShoulder != null) {
      final facingRatio =
          (lShoulder.x - rShoulder.x).abs() / math.max(1, bottomY - top.y);
      if (!sideView && facingRatio < 0.17) {
        return reset(CoachStatus.faceCamera,
            'Face the camera straight on', 'کیمرے کی طرف سیدھا رخ کریں');
      }
      if (sideView && facingRatio > 0.12) {
        return reset(
            CoachStatus.turnSide,
            'Turn to your right — keep turning until your side faces the '
                'camera',
            'دائیں طرف مڑیں — جب تک آپ کا پہلو کیمرے کی طرف نہ ہو');
      }
    }

    // Side view: hands drifting in front of the torso are the #1 cause of
    // inflated waist/hip readings — coach them away BEFORE the photo.
    if (sideView) {
      final hipX = lm(PoseLandmarkType.leftHip)?.x;
      final shX = lm(PoseLandmarkType.leftShoulder)?.x;
      if (hipX != null && shX != null) {
        final torsoDepthPx = (shX - hipX).abs() + w * 0.04;
        for (final t in [
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.rightWrist
        ]) {
          final wr = lm(t);
          if (wr != null && like(t) > 0.4 &&
              (wr.x - hipX).abs() > torsoDepthPx + w * 0.06) {
            return reset(CoachStatus.handsInFront,
                'Hands by your sides, not in front',
                'ہاتھ اطراف میں رکھیں، آگے نہیں');
          }
        }
      }
    }

    // Pose is good — require stillness for [holdDuration].
    final anchor = (x: top.x, y: top.y);
    final prev = _lastAnchor;
    _lastAnchor = anchor;
    final moved = prev == null
        ? double.infinity
        : math.sqrt(math.pow(anchor.x - prev.x, 2) +
            math.pow(anchor.y - prev.y, 2));
    if (moved > h * 0.015) {
      _stableSince = null;
      return const CoachResult(
          CoachStatus.hold, 'Good — hold still', 'اچھا — ساکت رہیں');
    }
    _stableSince ??= DateTime.now();
    final held = DateTime.now().difference(_stableSince!);
    // Belt and suspenders for the double-fire: no capture within 1.5s of
    // entering a stage, whatever the stability anchor says.
    final dwelt = DateTime.now().difference(_stageEnteredAt).inMilliseconds;
    if (held >= holdDuration && dwelt >= 1500) {
      _stableSince = null;
      return const CoachResult(CoachStatus.capture, 'Capturing!', 'تصویر لی جا رہی ہے',
          holdProgress: 1);
    }
    return CoachResult(CoachStatus.hold, 'Good — hold still', 'اچھا — ساکت رہیں',
        holdProgress: held.inMilliseconds / holdDuration.inMilliseconds);
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    // The controller is created with nv21 (Android) / bgra8888 (iOS), so
    // the frame is a single plane in both cases.
    final format = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;
    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> dispose() => _detector.close();
}

/// On-device voice coaching. Prefers Urdu when the device has an Urdu TTS
/// voice, otherwise speaks English. Speaks only on status CHANGE so it
/// coaches rather than nags.
class VoiceCoach {
  final FlutterTts _tts = FlutterTts();
  bool _urdu = false;
  bool _ready = false;
  CoachStatus? _lastSpoken;
  bool enabled = true;

  Future<void> init() async {
    try {
      final ur = await _tts.isLanguageAvailable('ur-PK');
      _urdu = ur == true;
      await _tts.setLanguage(_urdu ? 'ur-PK' : 'en-US');
      await _tts.setSpeechRate(0.5);
      _ready = true;
    } catch (_) {
      _ready = false; // silent coaching is still coaching
    }
  }

  Future<void> onResult(CoachResult r) async {
    if (!_ready || !enabled) return;
    if (r.status == _lastSpoken) return;
    // Never interrupt with "hold still" spam mid-progress.
    if (r.status == CoachStatus.hold && _lastSpoken == CoachStatus.capture) {
      return;
    }
    _lastSpoken = r.status;
    try {
      await _tts.stop();
      await _tts.speak(_urdu ? r.ur : r.en);
    } catch (_) {/* voice is best-effort */}
  }

  void resetFor(String stageName) {
    _lastSpoken = null;
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
