
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  TextRecognizer? _recognizer;
  bool _isProcessing = false;

  void _ensureInit() {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
  }

  Future<String> recognizeText(CameraImage image) async {
    _ensureInit();
    if (_isProcessing || _recognizer == null) return '';
    _isProcessing = true;

    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return '';

      final RecognizedText result =
          await _recognizer!.processImage(inputImage);

      final List<String> lines = [];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final String t = line.text.trim();
          // Only meaningful text: more than 2 chars, has letters/digits
          if (t.length > 2 && RegExp(r'[a-zA-Z0-9]').hasMatch(t)) {
            lines.add(t);
          }
        }
      }

      final String text = lines.join('. ');
      if (text.isNotEmpty) {
        debugPrint('OCR detected: $text');
      }
      return text;
    } catch (e) {
      debugPrint('OCR error: $e');
      return '';
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    try {
      if (image.planes.isEmpty) return null;

      final int width = image.width;
      final int height = image.height;

      final int yRowStride = image.planes[0].bytesPerRow;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      final int ySize = yRowStride * height;
      final int uvSize = uvRowStride * (height ~/ 2);
      final buffer = List<int>.filled(ySize + uvSize, 0);

      for (int row = 0; row < height; row++) {
        final int srcOffset = row * yRowStride;
        final int dstOffset = row * width;
        for (int col = 0; col < width; col++) {
          if (srcOffset + col < image.planes[0].bytes.length) {
            buffer[dstOffset + col] = image.planes[0].bytes[srcOffset + col];
          }
        }
      }

      final int uvOffset = width * height;
      for (int row = 0; row < height ~/ 2; row++) {
        for (int col = 0; col < width ~/ 2; col++) {
          final int uIdx = row * uvRowStride + col * uvPixelStride;
          final int vIdx = row * uvRowStride + col * uvPixelStride;
          final int dstIdx = uvOffset + (row * width + col * 2);

          if (dstIdx + 1 < buffer.length) {
            buffer[dstIdx] = vIdx < image.planes[2].bytes.length
                ? image.planes[2].bytes[vIdx]
                : 128;
            buffer[dstIdx + 1] = uIdx < image.planes[1].bytes.length
                ? image.planes[1].bytes[uIdx]
                : 128;
          }
        }
      }

      final Uint8List bytes = Uint8List.fromList(buffer);

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: width,
        ),
      );
    } catch (e) {
      debugPrint('OCR image conversion error: $e');
      return null;
    }
  }

  void dispose() {
    _recognizer?.close();
    _recognizer = null;
  }
}
