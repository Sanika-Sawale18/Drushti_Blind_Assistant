import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:vibration/vibration.dart';
import '../services/camera_service.dart';
import '../services/object_detection_service.dart';
import '../services/door_stairs_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/ocr_service.dart';
import '../models/detection_model.dart';
import '../utils/constants.dart';
import '../widgets/detection_overlay.dart';

class DetectionScreen extends StatefulWidget {
  final CameraService cameraService;
  final ObjectDetectionService detectionService;
  final TTSService ttsService;
  final SpeechService speechService;

  const DetectionScreen({
    super.key,
    required this.cameraService,
    required this.detectionService,
    required this.ttsService,
    required this.speechService,
  });

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with TickerProviderStateMixin {

  bool _isDetecting = false;
  List<DetectionResult> _detections = [];
  String _ocrText = '';
  bool _hazardActive = false;
  bool _navWarningActive = false; // door/stairs warning (not hazard)
  bool _showPanel = true;

  bool _isProcessing = false;
  int _frameCount = 0;
  int _doorStairsFrameCount = 0;
  int _ocrFrameCount = 0;

  // No-repeat tracking
  final Map<String, DateTime> _lastSpoken = {};
  static const Duration _normalCooldown  = Duration(seconds: 6);
  static const Duration _specialCooldown = Duration(seconds: 12);
  static const Duration _ocrCooldown     = Duration(seconds: 15);
  static const Set<String> _specialLabels = {'door', 'stairs'};

  // Hazard cooldown
  String _lastHazardLabel = '';
  DateTime _lastHazardTime = DateTime(2000);
  static const Duration _hazardCooldown = Duration(seconds: 5);

  final OcrService _ocr = OcrService();
  final DoorStairsService _doorStairs = DoorStairsService();

  late AnimationController _radarCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _hazardCtrl;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    _radarCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _hazardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350))
      ..repeat(reverse: true);

    widget.speechService.onCommand = _handleVoiceCommand;
    _doorStairs.loadModel();

    Future.delayed(const Duration(milliseconds: 300), _startDetection);
  }

  void _handleVoiceCommand(String cmd) {
    switch (cmd) {
      case 'start_detection': _startDetection(); break;
      case 'stop_detection':  _stopDetection();  break;
      case 'exit_app':        _exitApp();         break;
      case 'repeat':          _repeatLast();      break;
      case 'help':            _speakHelp();       break;
    }
  }

  void _startDetection() {
    if (_isDetecting) return;
    setState(() { _isDetecting = true; });
    _lastSpoken.clear();
    _doorStairs.reset();
    widget.cameraService.startImageStream(_onFrame);
    widget.ttsService.speak('Detection started. Scanning surroundings.');
  }

  void _stopDetection() {
    if (!_isDetecting) return;
    setState(() {
      _isDetecting = false;
      _detections = [];
      _ocrText = '';
      _hazardActive = false;
      _navWarningActive = false;
    });
    widget.cameraService.stopImageStream();
    widget.ttsService.speak('Detection paused.');
  }

  Future<void> _exitApp() async {
    _isDetecting = false;
    widget.ttsService.speak('Goodbye. Stay safe.');
    try { await widget.cameraService.stopImageStream(); } catch (_) {}
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) Get.back();
  }

  void _repeatLast() {
    _lastSpoken.clear();
    if (_detections.isNotEmpty || _ocrText.isNotEmpty) {
      _announceAll(_detections, _ocrText, force: true);
    } else {
      widget.ttsService.speak('No objects detected nearby.');
    }
  }

  void _speakHelp() {
    widget.ttsService.speak(
        'Say Stop to pause. Repeat to hear again. Exit to close app.');
  }

  Future<void> _onFrame(CameraImage image) async {
    if (!mounted || !_isDetecting) return;
    _frameCount++;
    _doorStairsFrameCount++;
    _ocrFrameCount++;

    if (_frameCount % 8 != 0) return;
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final List<DetectionResult> yolo =
          await widget.detectionService.detectObjects(image);

      // Pass YOLO results to door/stairs so it can apply blacklist
      Future<List<DetectionResult>> dsFuture = Future.value([]);
      if (_doorStairsFrameCount >= 16) {
        _doorStairsFrameCount = 0;
        // Pass yolo detections as context for blacklist
        dsFuture = _doorStairs.detect(image, yolo);
      }

      Future<String> ocrFuture = Future.value('');
      if (_ocrFrameCount >= 20) {
        _ocrFrameCount = 0;
        ocrFuture = _ocr.recognizeText(image);
      }

      final results = await Future.wait([dsFuture, ocrFuture]);
      final List<DetectionResult> special = results[0] as List<DetectionResult>;
      final String ocr = results[1] as String;

      if (!mounted) return;

      // Merge — add door/stairs only if not already in yolo list
      final List<DetectionResult> merged = List.from(yolo);
      for (final s in special) {
        merged.removeWhere((r) => r.label == s.label);
        merged.add(s);
      }

      // Sort: hazards first, navigation warnings second, rest by confidence
      merged.sort((a, b) {
        if (a.isHazard && !b.isHazard) return -1;
        if (!a.isHazard && b.isHazard) return 1;
        if (a.isNavigationWarning && !b.isNavigationWarning) return -1;
        if (!a.isNavigationWarning && b.isNavigationWarning) return 1;
        return b.confidence.compareTo(a.confidence);
      });

      final bool hazard = merged.any((d) => d.isHazard);
      final bool navWarn = merged.any((d) => d.isNavigationWarning);

      setState(() {
        if (merged.isNotEmpty) _detections = merged;
        if (ocr.isNotEmpty) _ocrText = ocr;
        _hazardActive = hazard;
        _navWarningActive = navWarn;
      });

      _announceAll(merged, ocr);

      // Hazard: only for dangerous moving objects (car, person, etc.)
      if (hazard) {
        final h = merged.firstWhere((d) => d.isHazard);
        final now = DateTime.now();
        if (h.label != _lastHazardLabel ||
            now.difference(_lastHazardTime) >= _hazardCooldown) {
          Vibration.vibrate(duration: 300);
          widget.ttsService.speakEmergency('${h.label} straight ahead!');
          _lastHazardLabel = h.label;
          _lastHazardTime = now;
        }
      }

      // Navigation warning: door/stairs — gentler alert, no emergency
      if (navWarn && !hazard) {
        final nw = merged.firstWhere((d) => d.isNavigationWarning);
        final DateTime? lastNw = _lastSpoken['__navwarn__'];
        final now = DateTime.now();
        if (lastNw == null ||
            now.difference(lastNw) >= const Duration(seconds: 12)) {
          Vibration.vibrate(duration: 150); 
          _lastSpoken['__navwarn__'] = now;
        }
      }

    } catch (e) {
      debugPrint('Frame error: $e');
    } finally {
      if (mounted) _isProcessing = false;
    }
  }

  void _announceAll(List<DetectionResult> detections, String ocr,
      {bool force = false}) {
    final DateTime now = DateTime.now();
    final List<String> parts = [];

    for (final d in detections.take(4)) {
      final Duration cooldown = _specialLabels.contains(d.label)
          ? _specialCooldown
          : _normalCooldown;
      final DateTime? last = _lastSpoken[d.label];
      if (force || last == null || now.difference(last) >= cooldown) {
        parts.add(d.toSpeechString());
        _lastSpoken[d.label] = now;
      }
    }

    if (ocr.isNotEmpty) {
      final DateTime? lastOcr = _lastSpoken['__ocr__'];
      if (force || lastOcr == null ||
          now.difference(lastOcr) >= _ocrCooldown) {
        parts.add('Text reads: $ocr');
        _lastSpoken['__ocr__'] = now;
      }
    }

    if (parts.isNotEmpty) {
      widget.ttsService.speak(parts.join('. '));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (widget.cameraService.controller?.value.isInitialized == true)
            Positioned.fill(
                child: CameraPreview(widget.cameraService.controller!)),

          AnimatedBuilder(
            animation: _radarCtrl,
            builder: (_, __) => DetectionOverlay(
              detections: _detections,
              ocrText: _ocrText,
              isScanning: _isDetecting,
              scanAngle: _radarCtrl.value * 2 * math.pi,
            ),
          ),

          // Hazard = RED border (dangerous)
          if (_hazardActive)
            AnimatedBuilder(
              animation: _hazardCtrl,
              builder: (_, __) => Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.hazard
                          .withValues(alpha: 0.7 * _hazardCtrl.value),
                      width: 5,
                    ),
                  ),
                ),
              ),
            ),

          if (_navWarningActive && !_hazardActive)
            AnimatedBuilder(
              animation: _hazardCtrl,
              builder: (_, __) => Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.warning
                          .withValues(alpha: 0.5 * _hazardCtrl.value),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12, right: 12,
            child: _topBar(),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            right: 66,
            child: GestureDetector(
              onTap: () => setState(() => _showPanel = !_showPanel),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  _showPanel ? Icons.visibility_off : Icons.list,
                  color: AppColors.accent, size: 18,
                ),
              ),
            ),
          ),

          if (_showPanel && (_detections.isNotEmpty || _ocrText.isNotEmpty))
            Positioned(
              left: 12, right: 12, bottom: 132,
              child: _infoPanel(),
            ),

          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 18,
            left: 16, right: 16,
            child: _controlBar(),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    String statusText;
    Color statusColor;

    if (_hazardActive) {
      statusText = '⚠  HAZARD DETECTED';
      statusColor = AppColors.hazard;
    } else if (_navWarningActive) {
      statusText = '⚠  DOOR / STAIRS AHEAD';
      statusColor = AppColors.warning;
    } else if (_isDetecting) {
      statusText = 'SCANNING';
      statusColor = AppColors.textPrimary;
    } else {
      statusText = 'PAUSED';
      statusColor = AppColors.textPrimary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (_hazardActive
              ? AppColors.hazard
              : (_navWarningActive ? AppColors.warning : AppColors.accent))
              .withValues(alpha: 0.4),
        ),
      ),
      child: Row(children: [
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hazardActive
                  ? AppColors.hazard
                  : (_navWarningActive
                      ? AppColors.warning
                      : (_isDetecting
                          ? AppColors.success
                          : AppColors.textSecondary)),
              boxShadow: _isDetecting
                  ? [BoxShadow(
                      color: (_hazardActive
                              ? AppColors.hazard
                              : AppColors.success)
                          .withValues(alpha: _pulseCtrl.value),
                      blurRadius: 6, spreadRadius: 2,
                    )]
                  : [],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            )),
        const Spacer(),
        if (_detections.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${_detections.length} obj',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }

  Widget _infoPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._detections.take(4).map((d) => DetectionChip(detection: d)),
        if (_ocrText.isNotEmpty) _ocrCard(),
      ],
    );
  }

  Widget _ocrCard() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ocrYellow.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(
            color: AppColors.ocrYellow.withValues(alpha: 0.12),
            blurRadius: 10)],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.text_fields, color: AppColors.ocrYellow, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_ocrText,
              style: const TextStyle(
                  color: AppColors.ocrYellow, fontSize: 12, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _controlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ctrlBtn(
            icon: _isDetecting ? Icons.pause : Icons.play_arrow,
            label: _isDetecting ? 'Pause' : 'Start',
            color: _isDetecting ? AppColors.warning : AppColors.success,
            onTap: _isDetecting ? _stopDetection : _startDetection,
          ),
          _ctrlBtn(icon: Icons.replay, label: 'Repeat',
              color: AppColors.accent, onTap: _repeatLast),
          _ctrlBtn(icon: Icons.help_outline, label: 'Help',
              color: AppColors.textSecondary, onTap: _speakHelp),
          _ctrlBtn(icon: Icons.close, label: 'Exit',
              color: AppColors.hazard, onTap: _exitApp),
        ],
      ),
    );
  }

  Widget _ctrlBtn({required IconData icon, required String label,
      required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  @override
  void dispose() {
    _isDetecting = false;
    _isProcessing = true;
    Future.microtask(() async {
      await widget.cameraService.stopImageStream();
      widget.cameraService.dispose();
      widget.detectionService.dispose();
      widget.ttsService.dispose();
      widget.speechService.dispose();
      _ocr.dispose();
      _doorStairs.dispose();
    });
    _radarCtrl.dispose();
    _pulseCtrl.dispose();
    _hazardCtrl.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}
