import 'dart:ui';

class UnifiedLandmark {
  final double x; // normalized 0..1 for web, or image-space for mobile
  final double y;
  final double z;
  final double visibility;

  const UnifiedLandmark({
    required this.x,
    required this.y,
    this.z = 0,
    this.visibility = 1,
  });
}

class UnifiedPose {
  // MediaPipe pose has 33 landmarks. We'll store by index.
  final List<UnifiedLandmark> landmarks;

  const UnifiedPose(this.landmarks);
}
