// lib/widgets/detection_overlay.dart
// Draws the scanning radar UI and detected objects info panel

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/detection_model.dart';
import '../utils/constants.dart';

/// Full-screen overlay showing radar scan effect + detection info
class DetectionOverlay extends StatelessWidget {
  final List<DetectionResult> detections;
  final String ocrText;
  final bool isScanning;
  final double scanAngle; // radians, from animation

  const DetectionOverlay({
    Key? key,
    required this.detections,
    required this.ocrText,
    required this.isScanning,
    required this.scanAngle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Radar sweep
        if (isScanning)
          Positioned.fill(
            child: CustomPaint(
              painter: _RadarSweepPainter(scanAngle),
            ),
          ),
        // Corner scan lines
        Positioned.fill(
          child: CustomPaint(
            painter: _ScanFramePainter(),
          ),
        ),
      ],
    );
  }
}

/// Draws the corner bracket lines around the camera view
class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const len = 28.0;
    const pad = 18.0;

    // Top-left
    canvas.drawLine(Offset(pad, pad), Offset(pad + len, pad), paint);
    canvas.drawLine(Offset(pad, pad), Offset(pad, pad + len), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - pad, pad),
        Offset(size.width - pad - len, pad), paint);
    canvas.drawLine(Offset(size.width - pad, pad),
        Offset(size.width - pad, pad + len), paint);
    // Bottom-left
    canvas.drawLine(Offset(pad, size.height - pad),
        Offset(pad + len, size.height - pad), paint);
    canvas.drawLine(Offset(pad, size.height - pad),
        Offset(pad, size.height - pad - len), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - pad, size.height - pad),
        Offset(size.width - pad - len, size.height - pad), paint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad),
        Offset(size.width - pad, size.height - pad - len), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Draws a radar sweep
class _RadarSweepPainter extends CustomPainter {
  final double angle;
  _RadarSweepPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(size.width, size.height) * 0.6;

    // Draw sweep gradient arc
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: angle - 0.6,
        endAngle: angle,
        colors: [
          Colors.transparent,
          AppColors.accent.withValues(alpha: 0.18),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, sweepPaint);

    // Sweep line
    final linePaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    final endX = center.dx + radius * math.cos(angle);
    final endY = center.dy + radius * math.sin(angle);
    canvas.drawLine(center, Offset(endX, endY), linePaint);
  }

  @override
  bool shouldRepaint(_RadarSweepPainter old) => old.angle != angle;
}

/// Card showing a single detected object
class DetectionChip extends StatelessWidget {
  final DetectionResult detection;

  const DetectionChip({Key? key, required this.detection}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isHazard = detection.isHazard;
    final color = isHazard ? AppColors.hazard : AppColors.accent;
    final glowColor = isHazard ? AppColors.hazardGlow : AppColors.accentGlow;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: Row(
        children: [
          // Direction icon
          _directionIcon(detection.direction, color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detection.label.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _locationText(detection),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Confidence badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(detection.confidence * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _directionIcon(String dir, Color color) {
    IconData icon;
    switch (dir) {
      case 'left':
        icon = Icons.arrow_back_ios;
        break;
      case 'right':
        icon = Icons.arrow_forward_ios;
        break;
      default:
        icon = Icons.arrow_upward;
    }
    return Icon(icon, color: color, size: 16);
  }

  String _locationText(DetectionResult d) {
    String dist = d.distanceEstimate != null
        ? ' · ~${d.distanceEstimate!.toStringAsFixed(1)}m'
        : '';
    return '${d.position} · ${d.direction}$dist';
  }
}
