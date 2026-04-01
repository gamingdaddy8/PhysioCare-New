import 'dart:math';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class BicepCurlCounter {
  // ==========================
  // SETTINGS (TUNE THESE)
  // ==========================
  final double upAngle = 60;     // arm bent
  final double downAngle = 160;  // arm straight
  final Duration holdDuration = const Duration(seconds: 3);

  // ==========================
  // STATE
  // ==========================
  int leftReps = 0;
  int rightReps = 0;

  String leftStage = "down";
  String rightStage = "down";

  double leftAngle = 0;
  double rightAngle = 0;

  DateTime? leftHoldStart;
  DateTime? rightHoldStart;

  int leftHoldElapsedSeconds() {
    if (leftHoldStart == null) return 0;
    return DateTime.now().difference(leftHoldStart!).inSeconds;
  }

  int rightHoldElapsedSeconds() {
    if (rightHoldStart == null) return 0;
    return DateTime.now().difference(rightHoldStart!).inSeconds;
  }

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
        leftShoulder.x, leftShoulder.y,
        leftElbow.x, leftElbow.y,
        leftWrist.x, leftWrist.y,
      );

      bool isUp = leftAngle < upAngle;
      bool isDown = leftAngle > downAngle;

      if (isDown) {
        if (leftStage == "up_done") leftReps++;
        leftStage = "down";
        leftHoldStart = null;
      } else if (isUp) {
        if (leftStage == "down") {
          leftStage = "holding";
          leftHoldStart = DateTime.now();
        } else if (leftStage == "holding") {
          if (DateTime.now().difference(leftHoldStart!) >= holdDuration) {
            leftStage = "up_done";
          }
        }
      } else {
        if (leftStage == "holding" && leftAngle > upAngle + 25) {
          leftStage = "down";
          leftHoldStart = null;
        }
      }
    }

    // RIGHT ARM
    if (rightShoulder != null && rightElbow != null && rightWrist != null) {
      rightAngle = _calculateAngle(
        rightShoulder.x, rightShoulder.y,
        rightElbow.x, rightElbow.y,
        rightWrist.x, rightWrist.y,
      );

      bool isUp = rightAngle < upAngle;
      bool isDown = rightAngle > downAngle;

      if (isDown) {
        if (rightStage == "up_done") rightReps++;
        rightStage = "down";
        rightHoldStart = null;
      } else if (isUp) {
        if (rightStage == "down") {
          rightStage = "holding";
          rightHoldStart = DateTime.now();
        } else if (rightStage == "holding") {
          if (DateTime.now().difference(rightHoldStart!) >= holdDuration) {
            rightStage = "up_done";
          }
        }
      } else {
        if (rightStage == "holding" && rightAngle > upAngle + 25) {
          rightStage = "down";
          rightHoldStart = null;
        }
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
    leftHoldStart = null;
    rightHoldStart = null;
  }

  // ==========================
  // ANGLE CALCULATION
  // ==========================
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
    return acos(cosAngle) * (180 / pi);
  }
}
