import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import '../models/detection_model.dart';

class ObjectDetectionService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isModelLoaded = false;
  bool _isProcessing = false;

  static const double _confThreshold = 0.45;
  static const int _inputSize = 640;

  bool get isModelLoaded => _isModelLoaded;

  Future<void> loadModel() async {
    try {
      final labelData =
          await rootBundle.loadString('assets/labels/coco_labels.txt');
      _labels = labelData
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final options = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = false;

      _interpreter = await Interpreter.fromAsset(
        'assets/models/yolomodel.tflite',
        options: options,
      );
      _isModelLoaded = true;
      debugPrint('YOLO loaded: ${_labels.length} classes');
    } catch (e) {
      debugPrint('Model load error: $e');
    }
  }

  Future<List<DetectionResult>> detectObjects(CameraImage image) async {
    if (!_isModelLoaded || _isProcessing || _interpreter == null) return [];
    _isProcessing = true;
    try {
      final input = await compute(_yuvToRgbFloat, _buildArgs(image));
      final rawOutput =
          List.filled(1 * 48 * 8400, 0.0).reshape([1, 48, 8400]);
      _interpreter!.run(input, rawOutput);
      final detections = await compute(_parseAndFilter, {
        'output': rawOutput[0] as List<List<double>>,
        'labels': _labels,
        'conf': _confThreshold,
        'inputSize': _inputSize,
      });
      return detections;
    } catch (e) {
      debugPrint('Detection error: $e');
      return [];
    } finally {
      _isProcessing = false;
    }
  }

  static Map<String, dynamic> _buildArgs(CameraImage img) => {
    'yBytes': img.planes[0].bytes,
    'uBytes': img.planes[1].bytes,
    'vBytes': img.planes[2].bytes,
    'width': img.width,
    'height': img.height,
    'rowStride': img.planes[0].bytesPerRow,
    'uvRowStride': img.planes[1].bytesPerRow,
    'uvPixelStride': img.planes[1].bytesPerPixel ?? 2,
  };

  void dispose() => _interpreter?.close();
}

// ── YUV→RGB float tensor
List<List<List<List<double>>>> _yuvToRgbFloat(Map<String, dynamic> d) {
  final Uint8List y = d['yBytes'];
  final Uint8List u = d['uBytes'];
  final Uint8List v = d['vBytes'];
  final int width = d['width'];
  final int height = d['height'];
  final int rowStride = d['rowStride'];
  final int uvRowStride = d['uvRowStride'];
  final int uvPixelStride = d['uvPixelStride'];
  const int size = 640;

  final buf = List.generate(1, (_) =>
      List.generate(size, (_) =>
          List.generate(size, (_) => List.filled(3, 0.0))));

  final double xScale = width / size;
  final double yScale = height / size;

  for (int row = 0; row < size; row++) {
    final int srcY = (row * yScale).toInt().clamp(0, height - 1);
    for (int col = 0; col < size; col++) {
      final int srcX = (col * xScale).toInt().clamp(0, width - 1);
      final int yIdx = (srcY * rowStride + srcX).clamp(0, y.length - 1);
      final int uvIdx =
          ((srcY >> 1) * uvRowStride + (srcX >> 1) * uvPixelStride)
              .clamp(0, math.min(u.length, v.length) - 1);

      final int yv = y[yIdx] & 0xFF;
      final int uv = u[uvIdx] & 0xFF;
      final int vv = v[uvIdx] & 0xFF;

      buf[0][row][col][0] =
          (yv + 1.370705 * (vv - 128)).round().clamp(0, 255) / 255.0;
      buf[0][row][col][1] =
          (yv - 0.337633 * (uv - 128) - 0.698001 * (vv - 128))
              .round().clamp(0, 255) / 255.0;
      buf[0][row][col][2] =
          (yv + 1.732446 * (uv - 128)).round().clamp(0, 255) / 255.0;
    }
  }
  return buf;
}

// ── Parse + per-class NMS 
List<DetectionResult> _parseAndFilter(Map<String, dynamic> args) {
  final List<List<double>> output = args['output'];
  final List<String> labels = args['labels'];
  final double confThresh = args['conf'];
  final int inputSize = args['inputSize'];

  // Collect raw boxes
  final List<_RawBox> raw = [];
  for (int i = 0; i < 8400; i++) {
    double maxScore = 0;
    int classId = -1;
    for (int c = 4; c < 84; c++) {
      if (output[c][i] > maxScore) {
        maxScore = output[c][i];
        classId = c - 4;
      }
    }
    if (maxScore < confThresh || classId < 0 || classId >= labels.length) {
      continue;
    }
    raw.add(_RawBox(
      label: labels[classId],
      classId: classId,
      conf: maxScore,
      cx: output[0][i] / inputSize,
      cy: output[1][i] / inputSize,
      w: output[2][i] / inputSize,
      h: output[3][i] / inputSize,
    ));
  }

  // NMS per class
  final List<_RawBox> kept = _nms(raw, iouThreshold: 0.45);

  // This prevents "LAPTOP LAPTOP LAPTOP" showing 3 times
  final Map<String, _RawBox> bestPerLabel = {};
  for (final b in kept) {
    if (!bestPerLabel.containsKey(b.label) ||
        b.conf > bestPerLabel[b.label]!.conf) {
      bestPerLabel[b.label] = b;
    }
  }

  final List<DetectionResult> results = bestPerLabel.values.map((b) {
    final String dir =
        b.cx < 0.33 ? 'left' : (b.cx > 0.67 ? 'right' : 'center');
    final String pos =
        b.cy < 0.40 ? 'top' : (b.cy > 0.60 ? 'bottom' : 'center');
    return DetectionResult(
      label: b.label,
      confidence: b.conf,
      position: pos,
      direction: dir,
      distanceEstimate: _estimateDist(b.label, b.w * b.h),
    );
  }).toList();

  results.sort((a, b) {
    if (a.isHazard && !b.isHazard) return -1;
    if (!a.isHazard && b.isHazard) return 1;
    return b.confidence.compareTo(a.confidence);
  });

  return results;
}

List<_RawBox> _nms(List<_RawBox> boxes, {double iouThreshold = 0.45}) {
  boxes.sort((a, b) => b.conf.compareTo(a.conf));
  final List<_RawBox> kept = [];
  final List<bool> suppressed = List.filled(boxes.length, false);
  for (int i = 0; i < boxes.length; i++) {
    if (suppressed[i]) continue;
    kept.add(boxes[i]);
    for (int j = i + 1; j < boxes.length; j++) {
      if (suppressed[j] || boxes[j].classId != boxes[i].classId) continue;
      if (_iou(boxes[i], boxes[j]) > iouThreshold) suppressed[j] = true;
    }
  }
  return kept;
}

double _iou(_RawBox a, _RawBox b) {
  final double ix1 = math.max(a.cx - a.w / 2, b.cx - b.w / 2);
  final double iy1 = math.max(a.cy - a.h / 2, b.cy - b.h / 2);
  final double ix2 = math.min(a.cx + a.w / 2, b.cx + b.w / 2);
  final double iy2 = math.min(a.cy + a.h / 2, b.cy + b.h / 2);
  if (ix2 < ix1 || iy2 < iy1) return 0.0;
  final double inter = (ix2 - ix1) * (iy2 - iy1);
  return inter / (a.w * a.h + b.w * b.h - inter).clamp(1e-6, 1.0);
}

double? _estimateDist(String label, double boxArea) {
  if (boxArea <= 0) return null;
  const Map<String, List<double>> refs = {
    'person':        [0.12, 2.0],  
    'car':           [0.15, 3.0],
    'motorcycle':    [0.10, 2.5],
    'bicycle':       [0.08, 2.0],
    'bus':           [0.25, 5.0],
    'truck':         [0.20, 4.0],
    'chair':         [0.08, 1.5],
    'couch':         [0.15, 2.0],
    'dining table':  [0.15, 2.0],
    'laptop':        [0.06, 0.8],  
    'tv':            [0.10, 1.5],
    'cell phone':    [0.02, 0.4],
    'keyboard':      [0.06, 0.7],
    'bottle':        [0.02, 0.8],
    'cup':           [0.015, 0.5],
    'dog':           [0.08, 1.5],
    'cat':           [0.05, 1.2],
    'bed':           [0.20, 2.0],
    'toilet':        [0.10, 1.5],
    'refrigerator':  [0.15, 2.0],
    'bench':         [0.10, 2.0],
  };
  final ref = refs[label] ?? [0.08, 2.0];
  final double dist = (ref[1] * math.sqrt(ref[0] / boxArea)).clamp(0.3, 12.0);
  return dist;
}

class _RawBox {
  final String label;
  final int classId;
  final double conf;
  final double cx, cy, w, h;

  const _RawBox({
    required this.label, required this.classId, required this.conf,
    required this.cx, required this.cy, required this.w, required this.h,
  });
}
