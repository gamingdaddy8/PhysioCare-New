import 'dart:math';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class BicepCurlCounter {
  // ==========================
  // SETTINGS (TUNE THESE)
  // ==========================
  final double upAngle = 60;     // arm bent
  final double downAngle = 160;  // arm straight

  // ==========================
  // STATE
  // ==========================
  int leftReps = 0;
  int rightReps = 0;

  String leftStage = "down";
  String rightStage = "down";

  double leftAngle = 0;
  double rightAngle = 0;

  // ==========================
  // MAIN UPDATE FUNCTION
  // ==========================
  void update(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];

    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    // LEFT ARM
    if (leftShoulder != null && leftElbow != null && leftWrist != null) {
      leftAngle = _calculateAngle(
        leftShoulder.x,
        leftShoulder.y,
        leftElbow.x,
        leftElbow.y,
        leftWrist.x,
        leftWrist.y,
      );

      // Stage logic
      if (leftAngle > downAngle) {
        leftStage = "down";
      }

      if (leftAngle < upAngle && leftStage == "down") {
        leftStage = "up";
        leftReps++;
      }
    }

    // RIGHT ARM
    if (rightShoulder != null && rightElbow != null && rightWrist != null) {
      rightAngle = _calculateAngle(
        rightShoulder.x,
        rightShoulder.y,
        rightElbow.x,
        rightElbow.y,
        rightWrist.x,
        rightWrist.y,
      );

      // Stage logic
      if (rightAngle > downAngle) {
        rightStage = "down";
      }

      if (rightAngle < upAngle && rightStage == "down") {
        rightStage = "up";
        rightReps++;
      }
    }
  }

  void reset() {
    leftReps = 0;
    rightReps = 0;
    leftStage = "down";
    rightStage = "down";
    leftAngle = 0;
    rightAngle = 0;
  }

  // ==========================
  // ANGLE CALCULATION
  // ==========================
  double _calculateAngle(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
  ) {
    // angle ABC (B = elbow)
    final abx = ax - bx;
    final aby = ay - by;

    final cbx = cx - bx;
    final cby = cy - by;

    final dot = (abx * cbx) + (aby * cby);
    final magAB = sqrt(abx * abx + aby * aby);
    final magCB = sqrt(cbx * cbx + cby * cby);

    final cosAngle = dot / (magAB * magCB);
    final angle = acos(cosAngle.clamp(-1.0, 1.0));

    return angle * (180 / pi);
  }
}
