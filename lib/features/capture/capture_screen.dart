import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/measure/engine.dart';
import '../results/results_screen.dart';
import 'live_coach.dart';
import 'pose_overlay.dart';

enum _Stage { intro, front, side, analyzing }

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  _Stage _stage = _Stage.intro;
  int _countdown = 0;
  Timer? _timer;
  String? _frontPath;
  String? _sidePath;
  String? _error;

  // Auto-capture: the live coach watches the stream and fires the shutter
  // itself; the timer stays available as a fallback.
  final LiveCoach _coach = LiveCoach();
  final VoiceCoach _voice = VoiceCoach();
  CoachResult? _coachResult;
  bool _autoMode = true;
  bool _shuttering = false;
  bool _streaming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _voice.init();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      // Back camera: someone else frames you, or prop the phone up.
      final cam = cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cams.first);
      final ctrl = CameraController(cam, ResolutionPreset.high,
          enableAudio: false,
          // Single-plane formats ML Kit reads directly from the stream.
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888);
      await ctrl.initialize();
      if (!mounted) return;
      setState(() => _camera = ctrl);
      _ensureStream();
    } catch (e) {
      setState(() => _error = 'Camera unavailable: $e');
    }
  }

  /// Starts the frame stream whenever we're on a camera stage in auto mode.
  Future<void> _ensureStream() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    final wantStream =
        _autoMode && (_stage == _Stage.front || _stage == _Stage.side);
    if (wantStream && !_streaming) {
      _streaming = true;
      await cam.startImageStream(_onFrame);
    } else if (!wantStream && _streaming) {
      _streaming = false;
      await cam.stopImageStream();
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final cam = _camera;
    if (cam == null || _shuttering || !_autoMode) return;
    if (_stage != _Stage.front && _stage != _Stage.side) return;
    final r = await _coach.process(image, cam.description,
        sideView: _stage == _Stage.side);
    if (r == null || !mounted || _shuttering) return;
    setState(() => _coachResult = r);
    await _voice.onResult(r);
    if (r.status == CoachStatus.capture) {
      await _capture();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _streaming = false;
      cam.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _camera?.dispose();
    _coach.dispose();
    _voice.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 7);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      if (_countdown <= 1) {
        t.cancel();
        setState(() => _countdown = 0);
        await _capture();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _capture() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized || _shuttering) return;
    _shuttering = true;
    try {
      if (_streaming) {
        _streaming = false;
        await cam.stopImageStream();
      }
      final file = await cam.takePicture();
      if (_stage == _Stage.front) {
        _frontPath = file.path;
        _voice.resetFor('side');
        setState(() {
          _stage = _Stage.side;
          _coachResult = null;
        });
        _shuttering = false;
        await _ensureStream();
      } else if (_stage == _Stage.side) {
        _sidePath = file.path;
        _shuttering = false;
        await _analyze();
      }
    } catch (e) {
      _shuttering = false;
      setState(() => _error = 'Capture failed: $e');
      await _ensureStream();
    }
  }

  Future<void> _analyze() async {
    final state = context.read<AppState>();
    setState(() => _stage = _Stage.analyzing);
    await _ensureStream(); // stops the stream
    final engine = MeasurementEngine();
    try {
      final result = await engine.analyze(
        frontImagePath: _frontPath!,
        sideImagePath: _sidePath!,
        profile: state.profile,
      );
      await engine.dispose();
      // Privacy contract: raw photos are deleted the moment analysis is done.
      await shredCaptures([_frontPath!, _sidePath!]);

      if (!mounted) return;
      if (result.hasBlockingIssues) {
        final msgs = result.issues.map((i) => '• ${i.message}').join('\n');
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Let's retake that"),
            content: Text(msgs),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Retake')),
            ],
          ),
        );
        if (mounted) {
          _voice.resetFor('front');
          setState(() {
            _stage = _Stage.front;
            _coachResult = null;
          });
          await _ensureStream();
        }
        return;
      }
      await state.setResult(result);
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ResultsScreen()));
    } catch (e) {
      await engine.dispose();
      if (mounted) {
        setState(() {
          _error = 'Analysis failed: $e';
          _stage = _Stage.front;
        });
        await _ensureStream();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(switch (_stage) {
          _Stage.intro => 'Guided capture',
          _Stage.front => 'Photo 1 of 2 — Front',
          _Stage.side => 'Photo 2 of 2 — Side',
          _Stage.analyzing => 'Measuring…',
        }),
        actions: [
          if (_stage == _Stage.front || _stage == _Stage.side)
            IconButton(
              tooltip: _voice.enabled ? 'Voice coach on' : 'Voice coach off',
              icon: Icon(
                  _voice.enabled ? Icons.volume_up : Icons.volume_off),
              onPressed: () =>
                  setState(() => _voice.enabled = !_voice.enabled),
            ),
        ],
      ),
      body: switch (_stage) {
        _Stage.intro => _buildIntro(),
        _Stage.analyzing => _buildAnalyzing(),
        _ => _buildCamera(),
      },
    );
  }

  Widget _buildIntro() {
    const steps = [
      (Icons.checkroom, 'Wear fitted clothes (not baggy) so the camera sees your shape.'),
      (Icons.light_mode, 'Stand in good, even light against a plain background.'),
      (Icons.straighten, 'Prop the phone at waist height, 2.5–3 m away — or have someone hold it.'),
      (Icons.accessibility_new, 'Front photo: stand tall, feet slightly apart, arms lifted ~30° from your sides.'),
      (Icons.rotate_90_degrees_ccw, 'Side photo: turn 90° to your right, hands relaxed at your sides.'),
      (Icons.record_voice_over, 'The app watches the camera, coaches you into place, and takes the photo itself when you are set.'),
      (Icons.lock, 'Photos are analyzed on your phone and deleted. They are never uploaded.'),
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final (icon, text) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(children: [
              Icon(icon, color: Colors.white70, size: 28),
              const SizedBox(width: 16),
              Expanded(
                  child: Text(text,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 15))),
            ]),
          ),
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!,
                style: const TextStyle(color: Colors.orangeAccent)),
          ),
        FilledButton(
          onPressed: _camera == null
              ? null
              : () async {
                  setState(() => _stage = _Stage.front);
                  await _ensureStream();
                },
          child: Text(_camera == null ? 'Starting camera…' : "I'm ready"),
        ),
      ],
    );
  }

  Widget _buildCamera() {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final isFront = _stage == _Stage.front;
    final coach = _coachResult;
    final good = coach != null &&
        (coach.status == CoachStatus.hold ||
            coach.status == CoachStatus.capture);
    return Stack(fit: StackFit.expand, children: [
      // The ghost overlay is a CHILD of the preview so its canvas is the
      // preview's own box — the outline then corresponds to the actual
      // photo frame.
      Center(
        child: CameraPreview(cam,
            child: CustomPaint(
                painter: PoseOverlayPainter(sideView: !isFront),
                child: const SizedBox.expand())),
      ),
      // Coach banner: live guidance in auto mode, static hint otherwise.
      Positioned(
        top: 16,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: good ? const Color(0xC81B4D3E) : Colors.black54,
            borderRadius: BorderRadius.circular(10),
          ),
          child: _autoMode && coach != null
              ? Column(children: [
                  Text(coach.en,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(coach.ur,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 15)),
                  if (coach.status == CoachStatus.hold &&
                      coach.holdProgress > 0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                        value: coach.holdProgress,
                        backgroundColor: Colors.white24,
                        color: Colors.white),
                  ],
                ])
              : Text(
                  isFront
                      ? 'Whole body between the two lines. Face the camera, '
                          'arms lifted slightly. Step back if you don\'t fit.'
                      : 'Turn 90° — right side to the camera. Hands relaxed '
                          'at your sides, NOT in front. Look straight ahead.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
        ),
      ),
      if (_countdown > 0)
        Center(
          child: Text(
            '$_countdown',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 120,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 20, color: Colors.black)]),
          ),
        ),
      Positioned(
        bottom: 32,
        left: 24,
        right: 24,
        child: Column(children: [
          if (_autoMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Auto-capture is watching — get in position.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54)),
                onPressed: _countdown > 0
                    ? null
                    : () async {
                        setState(() => _autoMode = !_autoMode);
                        await _ensureStream();
                      },
                icon: Icon(_autoMode
                    ? Icons.motion_photos_auto
                    : Icons.motion_photos_off),
                label: Text(_autoMode ? 'Auto: ON' : 'Auto: OFF'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _countdown > 0 ? null : _startCountdown,
                icon: const Icon(Icons.timer),
                label: Text(
                    _countdown > 0 ? 'Get in position…' : '7-sec timer'),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  Widget _buildAnalyzing() {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: Colors.white),
        SizedBox(height: 24),
        Text('Measuring on your phone…\nNothing is uploaded.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16)),
      ]),
    );
  }
}
