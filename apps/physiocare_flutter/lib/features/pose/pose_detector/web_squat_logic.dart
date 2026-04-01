import 'unified_pose.dart';
import 'unified_pose_utils.dart';

class WebSquatLogic {
  int reps = 0;
  bool _isLeftDown = false;
  bool _isRightDown = false;

  final double downThreshold;
  final double upThreshold;

  WebSquatLogic({
    this.downThreshold = 110,
    this.upThreshold = 160,
  });

  void reset() {
    reps = 0;
    _isLeftDown = false;
    _isRightDown = false;
  }

  String? update(UnifiedPose pose) {
    String? msg;
    bool repTriggered = false;

    // Left Leg
    final lhip = UnifiedPoseUtils.lm(pose, 23);
    final lknee = UnifiedPoseUtils.lm(pose, 25);
    final lankle = UnifiedPoseUtils.lm(pose, 27);

    if (UnifiedPoseUtils.visible(lhip) && UnifiedPoseUtils.visible(lknee) && UnifiedPoseUtils.visible(lankle)) {
      final angle = UnifiedPoseUtils.angleFrom3(lhip!, lknee!, lankle!);
      if (!_isLeftDown && angle < downThreshold) {
        _isLeftDown = true;
        msg = "Good! Now stand up";
      }
      if (_isLeftDown && angle > upThreshold) {
        repTriggered = true;
        _isLeftDown = false;
        msg = "Nice squat!";
      }
      if (!_isLeftDown && angle < 140 && msg == null) msg = "Go a bit lower";
    }

    // Right Leg
    final rhip = UnifiedPoseUtils.lm(pose, 24);
    final rknee = UnifiedPoseUtils.lm(pose, 26);
    final rankle = UnifiedPoseUtils.lm(pose, 28);

    if (UnifiedPoseUtils.visible(rhip) && UnifiedPoseUtils.visible(rknee) && UnifiedPoseUtils.visible(rankle)) {
      final angle = UnifiedPoseUtils.angleFrom3(rhip!, rknee!, rankle!);
      if (!_isRightDown && angle < downThreshold) {
        _isRightDown = true;
        msg = "Good! Now stand up";
      }
      if (_isRightDown && angle > upThreshold) {
        repTriggered = true;
        _isRightDown = false;
        msg = "Nice squat!";
      }
      if (!_isRightDown && angle < 140 && msg == null) msg = "Go a bit lower";
    }

    if (repTriggered) reps += 1;

    if (msg == null && 
       (!UnifiedPoseUtils.visible(lhip) || !UnifiedPoseUtils.visible(lknee) || !UnifiedPoseUtils.visible(lankle)) &&
       (!UnifiedPoseUtils.visible(rhip) || !UnifiedPoseUtils.visible(rknee) || !UnifiedPoseUtils.visible(rankle))) {
      return "Keep your legs visible";
    }

    return msg;
  }
}
