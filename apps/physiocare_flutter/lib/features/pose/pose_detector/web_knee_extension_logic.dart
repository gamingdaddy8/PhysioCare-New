import 'unified_pose.dart';
import 'unified_pose_utils.dart';

class WebKneeExtensionLogic {
  int leftReps = 0;
  int rightReps = 0;

  bool _isLeftUp = false;
  bool _isRightUp = false;

  double leftAngle = 0;
  double rightAngle = 0;

  String leftStage = 'Bend';
  String rightStage = 'Bend';

  final double upThreshold = 165;
  final double downThreshold = 110;

  void reset() {
    leftReps = 0;
    rightReps = 0;
    _isLeftUp = false;
    _isRightUp = false;
    leftAngle = 0;
    rightAngle = 0;
    leftStage = 'Bend';
    rightStage = 'Bend';
  }

  /// Returns feedback string
  String? update(UnifiedPose pose) {
    leftAngle = 0;
    rightAngle = 0;

    final lHip = UnifiedPoseUtils.lm(pose, 23);
    final lKnee = UnifiedPoseUtils.lm(pose, 25);
    final lAnkle = UnifiedPoseUtils.lm(pose, 27);

    final rHip = UnifiedPoseUtils.lm(pose, 24);
    final rKnee = UnifiedPoseUtils.lm(pose, 26);
    final rAnkle = UnifiedPoseUtils.lm(pose, 28);

    String? feedback;

    // Left leg
    if (UnifiedPoseUtils.visible(lHip) &&
        UnifiedPoseUtils.visible(lKnee) &&
        UnifiedPoseUtils.visible(lAnkle)) {
      leftAngle = UnifiedPoseUtils.angleFrom3(lHip!, lKnee!, lAnkle!);

      if (!_isLeftUp && leftAngle > upThreshold) {
        _isLeftUp = true;
        leftStage = 'Straight';
        feedback = "Hold the extension!";
      }

      if (_isLeftUp && leftAngle < downThreshold) {
        leftReps++;
        _isLeftUp = false;
        leftStage = 'Bend';
        feedback = "Nice left extension!";
      }
    }

    // Right leg
    if (UnifiedPoseUtils.visible(rHip) &&
        UnifiedPoseUtils.visible(rKnee) &&
        UnifiedPoseUtils.visible(rAnkle)) {
      rightAngle = UnifiedPoseUtils.angleFrom3(rHip!, rKnee!, rAnkle!);

      if (!_isRightUp && rightAngle > upThreshold) {
        _isRightUp = true;
        rightStage = 'Straight';
        feedback ??= "Hold the extension!";
      }

      if (_isRightUp && rightAngle < downThreshold) {
        rightReps++;
        _isRightUp = false;
        rightStage = 'Bend';
        feedback ??= "Nice right extension!";
      }
    }

    return feedback;
  }
}
