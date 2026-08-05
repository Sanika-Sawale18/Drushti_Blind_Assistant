class DetectionResult {
  final String label;
  final double confidence;
  final String position;
  final String direction;
  final double? distanceEstimate;

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.position,
    required this.direction,
    this.distanceEstimate,
  });

  String toSpeechString() {
    final String distStr = distanceEstimate != null
        ? ', ${distanceEstimate!.toStringAsFixed(1)} meters away'
        : '';
    final String pos = position == 'top'
        ? 'ahead'
        : (position == 'bottom' ? 'nearby' : 'in front');
    final String dir = direction == 'left'
        ? 'on your left'
        : (direction == 'right' ? 'on your right' : 'straight ahead');
    return '$label, $pos, $dir$distStr';
  }

  bool get isHazard {
    const Set<String> hazardLabels = {
      'person', 'car', 'motorcycle', 'bus', 'truck', 'bicycle',
    };
    return hazardLabels.contains(label) && direction == 'center';
  }

  bool get isNavigationWarning {
    return (label == 'door' || label == 'stairs') && direction == 'center';
  }

  @override
  String toString() =>
      '$label at $position-$direction '
      '(${(confidence * 100).toStringAsFixed(0)}%)';
}
