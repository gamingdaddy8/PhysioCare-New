import 'unified_pose.dart';
import 'unified_pose_utils.dart';

class WebSideRaiseLogic {
  int reps = 0;
  String stage = "down";
  DateTime? holdStart;
  final Duration holdDuration = const Duration(seconds: 3);

  // shoulder angle threshold
  final double upThreshold;
  final double downThreshold;

  WebSideRaiseLogic({
    this.upThreshold = 60,
    this.downThreshold = 25,
  });

  void reset() {
    reps = 0;
    stage = "down";
    holdStart = null;
  }

  String? update(UnifiedPose pose) {
    String? msg;

    final lhip = UnifiedPoseUtils.lm(pose, 23);
    final lsh = UnifiedPoseUtils.lm(pose, 11);
    final lel = UnifiedPoseUtils.lm(pose, 13);
    
    final rhip = UnifiedPoseUtils.lm(pose, 24);
    final rsh = UnifiedPoseUtils.lm(pose, 12);
    final rel = UnifiedPoseUtils.lm(pose, 14);

    bool leftVisible = UnifiedPoseUtils.visible(lhip) && UnifiedPoseUtils.visible(lsh) && UnifiedPoseUtils.visible(lel);
    bool rightVisible = UnifiedPoseUtils.visible(rhip) && UnifiedPoseUtils.visible(rsh) && UnifiedPoseUtils.visible(rel);

    if (!leftVisible && !rightVisible) return "Keep your sides visible";
    if (!leftVisible || !rightVisible) return "Keep both arms visible";

    final leftAngle = UnifiedPoseUtils.angleFrom3(lhip!, lsh!, lel!);
    final rightAngle = UnifiedPoseUtils.angleFrom3(rhip!, rsh!, rel!);

    bool leftIsUp = leftAngle > upThreshold;
    bool rightIsUp = rightAngle > upThreshold;
    
    bool leftIsDown = leftAngle < downThreshold;
    bool rightIsDown = rightAngle < downThreshold;

    if (stage == "down") {
      if (leftIsUp && rightIsUp) {
        stage = "holding";
        holdStart = DateTime.now();
        msg = "Hold it...";
      } else if (leftIsUp || rightIsUp) {
        msg = "Raise both arms together";
      } else if (leftAngle > 40 || rightAngle > 40) {
        msg = "Raise a bit more";
      }
    } else if (stage == "holding") {
      if (leftAngle < upThreshold - 20 || rightAngle < upThreshold - 20) {
        stage = "down";
        holdStart = null;
        msg = "Dropped early!";
      } else {
        final diff = DateTime.now().difference(holdStart!).inSeconds;
        if (diff >= holdDuration.inSeconds) {
          stage = "up_done";
          msg = "Good! Now lower slowly";
        } else {
          msg = "Hold... ${3 - diff}";
        }
      }
    } else if (stage == "up_done") {
      if (leftIsDown && rightIsDown) {
        stage = "down";
        holdStart = null;
        reps += 1;
        msg = "Nice rep!";
      } else if (leftIsDown || rightIsDown) {
        msg = "Lower both arms together";
      }
    }

    return msg;
  }
}
