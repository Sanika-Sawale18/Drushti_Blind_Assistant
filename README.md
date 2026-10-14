sha256:f8d9e65a640fcec23701244d98c898da2bfb29d315f7f9a1a4ba13e1fe3c0915
Drushti – Smart Blind Assistant 

Overview

Drushti is an AI-powered Android application designed to assist visually impaired individuals in understanding their surroundings. The application uses real-time object detection to identify objects captured through the smartphone camera and provides audio and haptic feedback to improve environmental awareness and support safer navigation.

Key Features

Real-Time Object Detection: Uses YOLOv8 with TensorFlow Lite to detect objects across 80 object categories.

Audio Feedback: Provides spoken information about detected objects.

Distance Estimation: Estimates the distance to detected objects to help users understand their surroundings.

Haptic Alerts: Provides vibration-based alerts for additional user feedback.

Offline Detection: Runs object detection locally using TensorFlow Lite without requiring continuous internet connectivity for inference.

Performance Optimization: Uses Dart Isolates to process camera frames and support smooth real-time execution.

Technology Stack

Frontend and Mobile App: Flutter

Programming Language: Dart

Object Detection: YOLOv8

Model Inference: TensorFlow Lite

Core Functionality: Camera frame processing, spatial audio feedback, distance estimation, and haptic alerts

Objective

The main objective of Drushti is to make smartphone-based assistive technology more accessible by providing real-time environmental information through audio and vibration, helping visually impaired users become more aware of nearby objects.

Future Enhancements

Improve detection performance in low-light conditions.

Add object tracking across consecutive video frames.

Integrate obstacle alerts based on estimated distance.

Evaluate performance across different environments and lighting conditions.
