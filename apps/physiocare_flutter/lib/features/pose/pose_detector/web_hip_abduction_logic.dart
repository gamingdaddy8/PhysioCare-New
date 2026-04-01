import 'unified_pose.dart';
import 'unified_pose_utils.dart';

class WebHipAbductionLogic {
  int leftReps = 0;
  int rightReps = 0;

  bool _isLeftUp = false;
  bool _isRightUp = false;

  double leftAngle = 0;
  double rightAngle = 0;

  String leftStage = 'Ready';
  String rightStage = 'Ready';

  final double upThreshold = 155;
  final double downThreshold = 170;

  void reset() {
    leftReps = 0;
    rightReps = 0;
    _isLeftUp = false;
    _isRightUp = false;
    leftAngle = 0;
    rightAngle = 0;
    leftStage = 'Ready';
    rightStage = 'Ready';
  }

  /// Returns feedback string
  String? update(UnifiedPose pose) {
    leftAngle = 0;
    rightAngle = 0;

    final lShoulder = UnifiedPoseUtils.lm(pose, 11);
    final lHip = UnifiedPoseUtils.lm(pose, 23);
    final lAnkle = UnifiedPoseUtils.lm(pose, 27);

    final rShoulder = UnifiedPoseUtils.lm(pose, 12);
    final rHip = UnifiedPoseUtils.lm(pose, 24);
    final rAnkle = UnifiedPoseUtils.lm(pose, 28);

    String? feedback;

    // Left leg
    if (UnifiedPoseUtils.visible(lShoulder) &&
        UnifiedPoseUtils.visible(lHip) &&
        UnifiedPoseUtils.visible(lAnkle)) {
      leftAngle = UnifiedPoseUtils.angleFrom3(lShoulder!, lHip!, lAnkle!);

      if (!_isLeftUp && leftAngle < upThreshold) {
        _isLeftUp = true;
        leftStage = 'Hold';
        feedback = "Good, hold it!";
      }

      if (_isLeftUp && leftAngle > downThreshold) {
        leftReps++;
        _isLeftUp = false;
        leftStage = 'Ready';
        feedback = "Nice left abduction!";
      }
    }

    // Right leg
    if (UnifiedPoseUtils.visible(rShoulder) &&
        UnifiedPoseUtils.visible(rHip) &&
        UnifiedPoseUtils.visible(rAnkle)) {
      rightAngle = UnifiedPoseUtils.angleFrom3(rShoulder!, rHip!, rAnkle!);

      if (!_isRightUp && rightAngle < upThreshold) {
        _isRightUp = true;
        rightStage = 'Hold';
        feedback ??= "Good, hold it!";
      }

      if (_isRightUp && rightAngle > downThreshold) {
        rightReps++;
        _isRightUp = false;
        rightStage = 'Ready';
        feedback ??= "Nice right abduction!";
      }
    }

    return feedback;
  }
}
