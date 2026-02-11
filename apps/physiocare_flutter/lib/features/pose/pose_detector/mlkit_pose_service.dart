import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class MLKitPoseService {
  late final PoseDetector _poseDetector;

  MLKitPoseService() {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    );

    _poseDetector = PoseDetector(options: options);
  }

  Future<List<Pose>> processImage(InputImage inputImage) async {
    return await _poseDetector.processImage(inputImage);
  }

  Future<void> dispose() async {
    await _poseDetector.close();
  }
}
