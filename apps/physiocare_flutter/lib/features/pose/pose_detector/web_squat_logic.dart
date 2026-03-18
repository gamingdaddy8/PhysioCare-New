import 'unified_pose.dart';
import 'unified_pose_utils.dart';

class WebSquatLogic {
  int reps = 0;
  bool _isDown = false;

  final double downThreshold;
  final double upThreshold;

  WebSquatLogic({
    this.downThreshold = 110,
    this.upThreshold = 160,
  });

  void reset() {
    reps = 0;
    _isDown = false;
  }

  /// Uses LEFT leg only
  /// hip=23, knee=25, ankle=27
  String? update(UnifiedPose pose) {
    final hip = UnifiedPoseUtils.lm(pose, 23);
    final knee = UnifiedPoseUtils.lm(pose, 25);
    final ankle = UnifiedPoseUtils.lm(pose, 27);

    if (!UnifiedPoseUtils.visible(hip) ||
        !UnifiedPoseUtils.visible(knee) ||
        !UnifiedPoseUtils.visible(ankle)) {
      return "Keep your left leg visible";
    }

    final angle = UnifiedPoseUtils.angleFrom3(hip!, knee!, ankle!);

    if (!_isDown && angle < downThreshold) {
      _isDown = true;
      return "Good! Now stand up";
    }

    if (_isDown && angle > upThreshold) {
      reps += 1;
      _isDown = false;
      return "Nice squat!";
    }

    if (!_isDown && angle < 140) return "Go a bit lower";
    return null;
  }
}
