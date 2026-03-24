import 'dart:math';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class KneeExtensionLogic {
  int leftReps = 0;
  int rightReps = 0;

  bool _isLeftUp = false;
  bool _isRightUp = false;

  double leftAngle = 0;
  double rightAngle = 0;

  String leftStage = 'Bend';
  String rightStage = 'Bend';

  // Seated knee bent is < 110. Straightened leg is > 165.
  final double upThreshold = 165;
  final double downThreshold = 110;

  DateTime _lastLeftRepTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRightRepTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration repCooldown = const Duration(milliseconds: 700);

  void reset() {
    leftReps = 0;
    rightReps = 0;
    _isLeftUp = false;
    _isRightUp = false;
    leftAngle = 0;
    rightAngle = 0;
    leftStage = 'Bend';
    rightStage = 'Bend';
    _lastLeftRepTime = DateTime.fromMillisecondsSinceEpoch(0);
    _lastRightRepTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  void update(Pose pose) {
    leftAngle = 0;
    rightAngle = 0;

    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final lKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final rHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    // Left leg logic
    if (lHip != null && lKnee != null && lAnkle != null) {
      leftAngle = _angle(lHip, lKnee, lAnkle);
      final now = DateTime.now();

      if (!_isLeftUp && leftAngle > upThreshold) {
        _isLeftUp = true;
        leftStage = 'Straight';
      }

      if (_isLeftUp && leftAngle < downThreshold) {
        if (now.difference(_lastLeftRepTime) >= repCooldown) {
          leftReps++;
          _lastLeftRepTime = now;
        }
        _isLeftUp = false;
        leftStage = 'Bend';
      }
    }

    // Right leg logic
    if (rHip != null && rKnee != null && rAnkle != null) {
      rightAngle = _angle(rHip, rKnee, rAnkle);
      final now = DateTime.now();

      if (!_isRightUp && rightAngle > upThreshold) {
        _isRightUp = true;
        rightStage = 'Straight';
      }

      if (_isRightUp && rightAngle < downThreshold) {
        if (now.difference(_lastRightRepTime) >= repCooldown) {
          rightReps++;
          _lastRightRepTime = now;
        }
        _isRightUp = false;
        rightStage = 'Bend';
      }
    }
  }

  double _angle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final abx = a.x - b.x, aby = a.y - b.y;
    final cbx = c.x - b.x, cby = c.y - b.y;
    final dot = abx * cbx + aby * cby;
    final magAB = sqrt(abx * abx + aby * aby);
    final magCB = sqrt(cbx * cbx + cby * cby);

    if (magAB == 0 || magCB == 0) return 180;
    final cosAngle = (dot / (magAB * magCB)).clamp(-1.0, 1.0);
    return acos(cosAngle) * (180 / pi);
  }
}
