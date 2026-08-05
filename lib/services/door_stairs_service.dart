import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../models/detection_model.dart';

class DoorStairsService {
  static final DoorStairsService _i = DoorStairsService._();
  factory DoorStairsService() => _i;
  DoorStairsService._();

  bool _isProcessing = false;

  int _doorConsecutive   = 0;
  int _stairsConsecutive = 0;
  static const int _requiredConsecutive = 2;

  // Very high thresholds to prevent false positives
  static const double _doorThreshold   = 0.78;
  static const double _stairsThreshold = 0.80;

  static const Set<String> _doorBlacklist = {
    'laptop', 'keyboard', 'tv', 'monitor', 'cell phone', 'remote',
    'mouse', 'book', 'bottle', 'cup', 'bowl', 'vase',
  };
  static const Set<String> _stairsBlacklist = {
    'laptop', 'keyboard', 'bed', 'couch', 'chair', 'dining table',
    'tv', 'cell phone', 'bottle', 'cup', 'bowl',
  };

  Future<void> loadModel() async {
    // No external model — pure image analysis
    debugPrint('DoorStairsService ready (Sobel analysis, strict mode)');
  }

  Future<List<DetectionResult>> detect(
      CameraImage image, List<DetectionResult> yoloDetections) async {
    if (_isProcessing) return [];
    _isProcessing = true;

    try {
      final Set<String> yoloLabels =
          yoloDetections.map((d) => d.label.toLowerCase()).toSet();

      final List<double> scores = await compute(_analyzeImage, {
        'yBytes':    image.planes[0].bytes,
        'width':     image.width,
        'height':    image.height,
        'rowStride': image.planes[0].bytesPerRow,
      });

      double doorScore   = scores[0];
      double stairsScore = scores[1];
      final String doorDir   = _dirFromNorm(scores[2]);
      final String stairsDir = _dirFromNorm(scores[3]);

      debugPrint(
          'DoorStairs raw → door:${doorScore.toStringAsFixed(2)} '
          'stairs:${stairsScore.toStringAsFixed(2)}');

      final bool doorBlacklisted =
          yoloLabels.any((l) => _doorBlacklist.contains(l));
      final bool stairsBlacklisted =
          yoloLabels.any((l) => _stairsBlacklist.contains(l));

      if (doorBlacklisted) {
        doorScore *= 0.30; // heavy penalty
        debugPrint('Door blacklisted by YOLO context');
      }
      if (stairsBlacklisted) {
        stairsScore *= 0.25;
        debugPrint('Stairs blacklisted by YOLO context');
      }

      // Frame consistency check
      if (doorScore >= _doorThreshold) {
        _doorConsecutive++;
      } else {
        _doorConsecutive = 0;
      }

      if (stairsScore >= _stairsThreshold) {
        _stairsConsecutive++;
      } else {
        _stairsConsecutive = 0;
      }

      final List<DetectionResult> results = [];

      // Only announce after N consecutive positive frames
      if (_doorConsecutive >= _requiredConsecutive) {
        results.add(DetectionResult(
          label: 'door',
          confidence: doorScore,
          position: 'center',
          direction: doorDir,
          distanceEstimate: 2.0,
        ));
        debugPrint('DOOR confirmed after $_doorConsecutive frames');
      }

      if (_stairsConsecutive >= _requiredConsecutive) {
        results.add(DetectionResult(
          label: 'stairs',
          confidence: stairsScore,
          position: 'bottom',
          direction: stairsDir,
          distanceEstimate: 1.5,
        ));
        debugPrint('STAIRS confirmed after $_stairsConsecutive frames');
      }

      return results;
    } catch (e) {
      debugPrint('DoorStairs detect error: $e');
      return [];
    } finally {
      _isProcessing = false;
    }
  }

  String _dirFromNorm(double cx) =>
      cx < 0.33 ? 'left' : (cx > 0.67 ? 'right' : 'center');

  void reset() {
    _doorConsecutive = 0;
    _stairsConsecutive = 0;
  }

  void dispose() {
    reset();
  }
}

// ── Isolate: strict Sobel analysis ────────────────────────────────────────────
List<double> _analyzeImage(Map<String, dynamic> d) {
  final Uint8List yPlane = d['yBytes'] as Uint8List;
  final int width        = d['width']  as int;
  final int height       = d['height'] as int;
  final int rowStride    = d['rowStride'] as int;

  const int G = 64;
  final double xScale = width  / G;
  final double yScale = height / G;

  final List<List<double>> gray = List.generate(G, (row) =>
    List.generate(G, (col) {
      final int srcX = (col * xScale).toInt().clamp(0, width - 1);
      final int srcY = (row * yScale).toInt().clamp(0, height - 1);
      final int idx  = (srcY * rowStride + srcX).clamp(0, yPlane.length - 1);
      return (yPlane[idx] & 0xFF).toDouble();
    })
  );

  // Sobel edge detection
  final List<List<double>> edgeV = List.generate(G, (_) => List.filled(G, 0.0));
  final List<List<double>> edgeH = List.generate(G, (_) => List.filled(G, 0.0));

  for (int r = 1; r < G - 1; r++) {
    for (int c = 1; c < G - 1; c++) {
      final double gx =
          (-gray[r-1][c-1] + gray[r-1][c+1]
          - 2.0*gray[r][c-1] + 2.0*gray[r][c+1]
          - gray[r+1][c-1] + gray[r+1][c+1]);
      final double gy =
          (-gray[r-1][c-1] - 2.0*gray[r-1][c] - gray[r-1][c+1]
          + gray[r+1][c-1] + 2.0*gray[r+1][c] + gray[r+1][c+1]);
      edgeV[r][c] = gx.abs();
      edgeH[r][c] = gy.abs();
    }
  }

  // Column vertical strength
  final List<double> colVStr = List.filled(G, 0.0);
  for (int c = 0; c < G; c++) {
    double sum = 0;
    for (int r = 5; r < G - 5; r++) sum += edgeV[r][c];
    colVStr[c] = sum / (G - 10);
  }

  // Row horizontal strength
  final List<double> rowHStr = List.filled(G, 0.0);
  for (int r = 0; r < G; r++) {
    double sum = 0;
    for (int c = 5; c < G - 5; c++) sum += edgeH[r][c];
    rowHStr[r] = sum / (G - 10);
  }

  double leftPeak = 0; int leftCol = 0;
  double rightPeak = 0; int rightCol = G - 1;

  for (int c = 2; c < G ~/ 2; c++) {
    if (colVStr[c] > leftPeak) { leftPeak = colVStr[c]; leftCol = c; }
  }
  for (int c = G ~/ 2; c < G - 2; c++) {
    if (colVStr[c] > rightPeak) { rightPeak = colVStr[c]; rightCol = c; }
  }

  int leftSustained = 0, rightSustained = 0;
  for (int r = 5; r < G - 5; r++) {
    if (edgeV[r][leftCol]  > 60) leftSustained++;
    if (edgeV[r][rightCol] > 60) rightSustained++;
  }

  final double doorWidth = (rightCol - leftCol) / G;
  final double doorCx    = (leftCol + rightCol) / 2.0 / G;

  double maxTopHoriz = 0;
  for (int r = 0; r < (G * 0.35).toInt(); r++) {
    if (rowHStr[r] > maxTopHoriz) maxTopHoriz = rowHStr[r];
  }

  double outsideEdge = 0;
  for (int c = 0; c < G; c++) {
    if (c < leftCol - 3 || c > rightCol + 3) {
      outsideEdge += colVStr[c];
    }
  }
  outsideEdge /= math.max(1, G - (rightCol - leftCol + 6));

  double doorScore = 0.0;

  final bool strongLines    = leftPeak > 80 && rightPeak > 80;
  final bool goodWidth      = doorWidth > 0.15 && doorWidth < 0.55;
  final bool sustained      = leftSustained > 15 && rightSustained > 15;
  final bool hasHeader      = maxTopHoriz > 50;
  final bool cleanBackground = outsideEdge < leftPeak * 0.4;

  if (strongLines && goodWidth && sustained) {
    doorScore = 0.70;
    if (hasHeader)        doorScore += 0.12;
    if (cleanBackground)  doorScore += 0.10;
    if (leftPeak > 120 && rightPeak > 120) doorScore += 0.08;
    final double centeredness = 1.0 - (doorCx - 0.5).abs() * 2.0;
    doorScore *= math.max(0.4, centeredness);
  }


  final int lowerStart = (G * 0.45).toInt();
  final int lowerLen   = G - lowerStart;

  final List<double> lowerHStr = List.generate(
    lowerLen, (i) => rowHStr[lowerStart + i],
  );

  final List<int> peaks = [];
  for (int i = 1; i < lowerLen - 1; i++) {
    if (lowerHStr[i] > 30 &&                          
        lowerHStr[i] > lowerHStr[i - 1] &&
        lowerHStr[i] > lowerHStr[i + 1]) {
      peaks.add(i);
    }
  }

  double stairsScore = 0.0;
  double stairsCx    = 0.5;

  if (peaks.length >= 4) {                            
    final List<int> gaps = [];
    for (int i = 1; i < peaks.length; i++) {
      gaps.add(peaks[i] - peaks[i - 1]);
    }
    final double avgGap = gaps.fold(0, (a, b) => a + b) / gaps.length;
    double variance = 0;
    for (final g in gaps) variance += (g - avgGap) * (g - avgGap);
    variance /= gaps.length;

    final bool goodSpacing  = avgGap >= 2 && avgGap <= 12;
    final bool veryRegular  = variance < 5.0;        

    double avgWidth = 0;
    for (final row in peaks) {
      int cnt = 0;
      for (int c = 0; c < G; c++) {
        if (edgeH[lowerStart + row][c] > 20) cnt++;
      }
      avgWidth += cnt / G;
    }
    avgWidth /= peaks.length;
    final bool wideEdges = avgWidth > 0.50;            

    double vertDominance = 0;
    for (int r = lowerStart; r < G; r++) {
      for (int c = 0; c < G; c++) {
        vertDominance += edgeV[r][c];
      }
    }
    vertDominance /= (lowerLen * G);
    final bool notVertical = vertDominance < 25;       

    if (goodSpacing && veryRegular && wideEdges && notVertical) {
      stairsScore = 0.72;
      if (peaks.length >= 5) stairsScore += 0.08;
      if (peaks.length >= 6) stairsScore += 0.05;
    }

    double maxSum = 0; int maxCol = G ~/ 2;
    for (int c = 0; c < G; c++) {
      double colSum = 0;
      for (final row in peaks) colSum += edgeH[lowerStart + row][c];
      if (colSum > maxSum) { maxSum = colSum; maxCol = c; }
    }
    stairsCx = maxCol / G;
  }

  return [
    doorScore.clamp(0.0, 1.0),
    stairsScore.clamp(0.0, 1.0),
    doorCx,
    stairsCx,
  ];
}
