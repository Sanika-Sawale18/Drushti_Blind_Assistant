import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? controller;
  bool _isStopping = false;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  CameraController? get cameraController => controller;

  Future<bool> initialize() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      debugPrint('Camera permission denied');
      return false;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      debugPrint('No cameras available');
      return false;
    }

    controller = CameraController(
      cameras[0], // Back camera
      ResolutionPreset.medium, 
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await controller!.initialize();
      _isInitialized = true;
      debugPrint('Camera initialized: ${cameras[0].name}');
      return true;
    } catch (e) {
      debugPrint('Camera init error: $e');
      _isInitialized = false;
      return false;
    }
  }

  void startImageStream(Function(CameraImage) onImage) {
    if (controller == null ||
        !controller!.value.isInitialized ||
        controller!.value.isStreamingImages) return;

    controller!.startImageStream((image) {
      if (_isStopping) return;
      onImage(image);
    });
  }

  Future<void> stopImageStream() async {
    if (controller != null && controller!.value.isStreamingImages) {
      _isStopping = true;
      try {
        await controller!.stopImageStream();
      } catch (e) {
        debugPrint('Stop stream error: $e');
      }
      _isStopping = false;
    }
  }

  void dispose() {
    _isInitialized = false;
    controller?.dispose();
    controller = null;
  }
}
