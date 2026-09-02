import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/measure/engine.dart';
import '../results/results_screen.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      // Back camera: someone else frames you, or prop the phone up.
      final cam = cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cams.first);
      final ctrl = CameraController(cam, ResolutionPreset.high,
          enableAudio: false);
      await ctrl.initialize();
      if (!mounted) return;
      setState(() => _camera = ctrl);
    } catch (e) {
      setState(() => _error = 'Camera unavailable: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
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
    if (cam == null || !cam.value.isInitialized) return;
    try {
      final file = await cam.takePicture();
      if (_stage == _Stage.front) {
        _frontPath = file.path;
        setState(() => _stage = _Stage.side);
      } else if (_stage == _Stage.side) {
        _sidePath = file.path;
        await _analyze();
      }
    } catch (e) {
      setState(() => _error = 'Capture failed: $e');
    }
  }

  Future<void> _analyze() async {
    setState(() => _stage = _Stage.analyzing);
    final state = context.read<AppState>();
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
        if (mounted) setState(() => _stage = _Stage.front);
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
      (Icons.rotate_90_degrees_ccw, 'Side photo: turn 90° to your right, arms relaxed slightly forward.'),
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
          onPressed:
              _camera == null ? null : () => setState(() => _stage = _Stage.front),
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
    return Stack(fit: StackFit.expand, children: [
      // The ghost overlay is a CHILD of the preview so its canvas is the
      // preview's own box — the outline then corresponds to the actual
      // photo frame. Painted full-screen it floats over letterbox areas
      // the camera never captures, guiding people into cropped photos.
      Center(
        child: CameraPreview(cam,
            child: CustomPaint(
                painter: PoseOverlayPainter(sideView: !isFront),
                child: const SizedBox.expand())),
      ),
      Positioned(
        top: 16,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            isFront
                ? 'Whole body between the two lines — head near the top line, '
                    'feet on the bottom one. Face the camera, arms lifted '
                    'slightly. Step back if you don\'t fit.'
                : 'Turn 90° — right side to the camera. Hands relaxed at '
                    'your sides, NOT in front of your body. Look straight '
                    'ahead.',
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
        child: FilledButton.icon(
          onPressed: _countdown > 0 ? null : _startCountdown,
          icon: const Icon(Icons.timer),
          label: Text(_countdown > 0
              ? 'Get in position…'
              : 'Start 7-second timer'),
        ),
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
