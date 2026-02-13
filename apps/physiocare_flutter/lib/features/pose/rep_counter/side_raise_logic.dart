import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class SideRaiseLogic {
  int leftReps = 0;
  int rightReps = 0;

  double leftAngle = 0;
  double rightAngle = 0;

  String leftStage = "down";
  String rightStage = "down";

  // Thresholds
  final double upThreshold;
  final double downThreshold;
  final double smoothFactor;

  double _leftSmoothed = 0;
  double _rightSmoothed = 0;

  SideRaiseLogic({
    this.upThreshold = 80,
    this.downThreshold = 35,
    this.smoothFactor = 0.7,
  });

  void reset() {
    leftReps = 0;
    rightReps = 0;
    leftAngle = 0;
    rightAngle = 0;
    leftStage = "down";
    rightStage = "down";
    _leftSmoothed = 0;
    _rightSmoothed = 0;
  }

  void update(Pose pose) {
    _updateLeft(pose);
    _updateRight(pose);
  }

  // LEFT ARM: Hip -> Shoulder -> Elbow
  void _updateLeft(Pose pose) {
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.leftElbow];

    if (hip == null || shoulder == null || elbow == null) return;

    final raw = _calculateAngle(
      hip.x, hip.y,
      shoulder.x, shoulder.y,
      elbow.x, elbow.y,
    );

    _leftSmoothed = (_leftSmoothed == 0)
        ? raw
        : (_leftSmoothed * smoothFactor) + (raw * (1 - smoothFactor));

    leftAngle = _leftSmoothed;

    if (leftAngle < downThreshold) {
      leftStage = "down";
    }

    if (leftAngle > upThreshold && leftStage == "down") {
      leftStage = "up";
      leftReps++;
    }
  }

  // RIGHT ARM: Hip -> Shoulder -> Elbow
  void _updateRight(Pose pose) {
    final hip = pose.landmarks[PoseLandmarkType.rightHip];
    final shoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.rightElbow];

    if (hip == null || shoulder == null || elbow == null) return;

    final raw = _calculateAngle(
      hip.x, hip.y,
      shoulder.x, shoulder.y,
      elbow.x, elbow.y,
    );

    _rightSmoothed = (_rightSmoothed == 0)
        ? raw
        : (_rightSmoothed * smoothFactor) + (raw * (1 - smoothFactor));

    rightAngle = _rightSmoothed;

    if (rightAngle < downThreshold) {
      rightStage = "down";
    }

    if (rightAngle > upThreshold && rightStage == "down") {
      rightStage = "up";
      rightReps++;
    }
  }

  double _calculateAngle(
    double ax, double ay,
    double bx, double by,
    double cx, double cy,
  ) {
    final abx = ax - bx;
    final aby = ay - by;
    final cbx = cx - bx;
    final cby = cy - by;

    final dot = (abx * cbx) + (aby * cby);
    final magAB = sqrt(abx * abx + aby * aby);
    final magCB = sqrt(cbx * cbx + cby * cby);

    if (magAB == 0 || magCB == 0) return 0;

    final cosAngle = (dot / (magAB * magCB)).clamp(-1.0, 1.0);
    final angleRad = acos(cosAngle);

    return angleRad * (180 / pi);
  }
}
