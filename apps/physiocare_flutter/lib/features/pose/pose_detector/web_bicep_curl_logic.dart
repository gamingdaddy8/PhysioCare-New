import 'unified_pose.dart';
import 'unified_pose_utils.dart';

class WebBicepCurlLogic {
  int reps = 0;
  bool _isUp = false;

  final double upThreshold;
  final double downThreshold;

  WebBicepCurlLogic({
    this.upThreshold = 55,
    this.downThreshold = 155,
  });

  void reset() {
    reps = 0;
    _isUp = false;
  }

  /// Uses LEFT arm only (MediaPipe indices)
  /// shoulder=11, elbow=13, wrist=15
  String? update(UnifiedPose pose) {
    final s = UnifiedPoseUtils.lm(pose, 11);
    final e = UnifiedPoseUtils.lm(pose, 13);
    final w = UnifiedPoseUtils.lm(pose, 15);

    if (!UnifiedPoseUtils.visible(s) ||
        !UnifiedPoseUtils.visible(e) ||
        !UnifiedPoseUtils.visible(w)) {
      return "Keep your left arm visible";
    }

    final angle = UnifiedPoseUtils.angleFrom3(s!, e!, w!);

    // down -> up -> down
    if (!_isUp && angle < upThreshold) {
      _isUp = true;
      return "Good! Now extend";
    }

    if (_isUp && angle > downThreshold) {
      reps += 1;
      _isUp = false;
      return "Nice rep!";
    }

    if (!_isUp && angle < 90) return "Curl higher";
    return null;
  }
}
