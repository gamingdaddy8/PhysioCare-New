import 'unified_pose.dart';
import 'unified_pose_utils.dart';

class WebSideRaiseLogic {
  int reps = 0;
  bool _isUp = false;

  // shoulder angle threshold
  final double upThreshold;
  final double downThreshold;

  WebSideRaiseLogic({
    this.upThreshold = 60,
    this.downThreshold = 25,
  });

  void reset() {
    reps = 0;
    _isUp = false;
  }

  /// Uses LEFT arm only
  /// hip=23, shoulder=11, elbow=13
  String? update(UnifiedPose pose) {
    final hip = UnifiedPoseUtils.lm(pose, 23);
    final sh = UnifiedPoseUtils.lm(pose, 11);
    final el = UnifiedPoseUtils.lm(pose, 13);

    if (!UnifiedPoseUtils.visible(hip) ||
        !UnifiedPoseUtils.visible(sh) ||
        !UnifiedPoseUtils.visible(el)) {
      return "Keep your left side visible";
    }

    // Angle at shoulder between hip-shoulder-elbow
    final angle = UnifiedPoseUtils.angleFrom3(hip!, sh!, el!);

    // down -> up -> down
    if (!_isUp && angle > upThreshold) {
      _isUp = true;
      return "Good! Now lower slowly";
    }

    if (_isUp && angle < downThreshold) {
      reps += 1;
      _isUp = false;
      return "Nice rep!";
    }

    if (!_isUp && angle > 40) return "Raise a bit more";
    return null;
  }
}
