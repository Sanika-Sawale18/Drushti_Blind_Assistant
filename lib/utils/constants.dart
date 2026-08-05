import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0A0E27);
  static const Color primaryLight = Color(0xFF1A1F45);
  static const Color accent = Color(0xFF00D4FF);
  static const Color accentGlow = Color(0x4400D4FF);
  static const Color warning = Color(0xFFFF6B35);
  static const Color warningGlow = Color(0x44FF6B35);
  static const Color success = Color(0xFF00E676);
  static const Color successGlow = Color(0x4400E676);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color surface = Color(0xFF0D1B3E);
  static const Color cardBg = Color(0x99101D3A);
  static const Color hazard = Color(0xFFFF1744);
  static const Color hazardGlow = Color(0x44FF1744);
  static const Color ocrYellow = Color(0xFFFFD600);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.success,
          surface: AppColors.surface,
          error: AppColors.hazard,
        ),
        useMaterial3: true,
      );
}

class AppStrings {
  static const String appName = 'DRUSHTI';
  static const String tagline = 'Vision for Everyone';
  static const String welcomeMsg =
      'Welcome to Drushti. Your smart blind assistant is ready.';
  static const String startPrompt =
      'Tap the screen or say Start to begin detection.';
  static const String detectionStarted = 'Detection started. Scanning your surroundings.';
  static const String detectionPaused = 'Detection paused.';
  static const String goodbye = 'Goodbye. Stay safe.';
  static const String noDetections = 'No objects detected nearby.';
  static const String hazardAlert = 'Warning!';
}

class AppDimensions {
  static const double borderRadius = 20.0;
  static const double cardRadius = 16.0;
  static const double buttonSize = 70.0;
  static const double iconSizeLarge = 48.0;
  static const double iconSizeMedium = 30.0;
  static const double iconSizeSmall = 20.0;
}

const List<String> kHazardLabels = [
  'person', 'car', 'motorcycle', 'bus', 'truck', 'bicycle',
  'fire hydrant', 'stop sign', 'traffic light',
];

const List<String> kIndoorLabels = [
  'chair', 'couch', 'bed', 'dining table', 'toilet',
  'tv', 'laptop', 'refrigerator', 'sink', 'door',
];
