import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/camera_service.dart';
import '../services/object_detection_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import 'detection_screen.dart';

class StartScreen extends StatefulWidget {
  final CameraService cameraService;
  final ObjectDetectionService detectionService;
  final TTSService ttsService;
  final SpeechService speechService;

  const StartScreen({
    super.key,
    required this.cameraService,
    required this.detectionService,
    required this.ttsService,
    required this.speechService,
  });

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  @override
  void initState() {
    super.initState();
    widget.speechService.onCommand = (cmd) {
      if (cmd == 'start_detection') _goToDetection();
    };
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.ttsService.speak(
          'Welcome to Drushti Blind Assistant. Tap anywhere on the screen to start.');
    });
  }

  void _goToDetection() {
    Get.off(() => DetectionScreen(
          cameraService: widget.cameraService,
          detectionService: widget.detectionService,
          ttsService: widget.ttsService,
          speechService: widget.speechService,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goToDetection,
      child: const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app,
                color: Colors.white54,
                size: 64,
              ),
              SizedBox(height: 32),
              Text(
                'TAP TO START',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 6,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'or say  "Start"',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white54,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
