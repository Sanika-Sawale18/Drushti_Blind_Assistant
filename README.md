# Drushti – Smart Blind Assistant

Drushti is an AI-powered Android application designed to assist visually impaired individuals by providing information about their surroundings through real-time object detection and audio and haptic feedback.

The application uses YOLOv8 with TensorFlow Lite to detect objects from the smartphone camera. It supports offline model inference and combines object detection with distance estimation, spatial audio feedback, and vibration alerts to improve environmental awareness.

---

## Key Features

- **Real-Time Object Detection** — Detects objects from the smartphone camera using YOLOv8 and TensorFlow Lite.
- **80 Object Categories** — Identifies objects across 80 supported categories.
- **Audio Feedback** — Provides spoken feedback about detected objects.
- **Distance Estimation** — Estimates the distance to detected objects.
- **Spatial Audio Feedback** — Uses audio cues to help users understand where detected objects are located.
- **Haptic Alerts** — Provides vibration-based feedback.
- **Offline Inference** — Runs object detection on-device using TensorFlow Lite without requiring continuous internet access for inference.
- **Camera Frame Processing** — Uses Dart Isolates to support smooth processing of camera frames.

---

## Technology Stack

### Mobile Application

- Flutter
- Dart

### Computer Vision & AI

- YOLOv8
- TensorFlow Lite
- Real-time camera frame processing

### Accessibility Features

- Text-to-speech / audio feedback
- Spatial audio cues
- Haptic feedback
- Distance estimation

---

## How It Works

1. The smartphone camera captures the user's surroundings.
2. Camera frames are processed by the application.
3. The YOLOv8 model, running through TensorFlow Lite, detects supported objects.
4. The application uses the detection results to provide audio and haptic feedback.
5. Distance estimation helps provide additional context about detected objects.

---

## Project Objective

The objective of Drushti is to explore how computer vision and mobile technology can support visually impaired individuals by communicating information about nearby objects through accessible audio and vibration cues.

---

## Future Enhancements

- Improve detection performance in different lighting and environmental conditions.
- Add object tracking across consecutive video frames.
- Enhance obstacle-warning logic using distance estimates.
- Evaluate detection accuracy and application performance in real-world scenarios.

---

## Safety Note

Drushti is an assistive technology project and should not be considered a replacement for a white cane, guide dog, or other established mobility aids. Users should continue to follow safe mobility practices.

---

## Author

**Sanika Sawale**

- GitHub: [Sanika-Sawale18](https://github.com/Sanika-Sawale18)
- LinkedIn: [sanikasawale](https://linkedin.com/in/sanikasawale)

---

> **Note:** Update this README with installation steps, screenshots, a demo video, model details, and measured results when those materials are available. Keep only the features that are implemented and tested in your project.
