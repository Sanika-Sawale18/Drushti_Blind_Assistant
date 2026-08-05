import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/camera_service.dart';
import '../services/object_detection_service.dart';
import 'start_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final TTSService _tts = TTSService();
  final SpeechService _speech = SpeechService();
  final ObjectDetectionService _detector = ObjectDetectionService();
  final CameraService _camera = CameraService();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _tts.init();
    await _camera.initialize();
    await _detector.loadModel();
    await _speech.init();

    // Show splash for at least 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Get.off(() => StartScreen(
            cameraService: _camera,
            detectionService: _detector,
            ttsService: _tts,
            speechService: _speech,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Drushti',
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Blind Assistant',
              style: TextStyle(
                fontSize: 22,
                color: Colors.white70,
                letterSpacing: 2,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
