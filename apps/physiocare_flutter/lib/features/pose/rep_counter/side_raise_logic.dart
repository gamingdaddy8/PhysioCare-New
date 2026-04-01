import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class SideRaiseLogic {
  int reps = 0;

  double leftAngle = 0;
  double rightAngle = 0;

  String stage = "down";
  DateTime? holdStart;

  final Duration holdDuration = const Duration(seconds: 3);

  int holdElapsedSeconds() {
    if (holdStart == null) return 0;
    return DateTime.now().difference(holdStart!).inSeconds;
  }

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
    reps = 0;
    leftAngle = 0;
    rightAngle = 0;
    stage = "down";
    _leftSmoothed = 0;
    _rightSmoothed = 0;
    holdStart = null;
  }

  void update(Pose pose) {
    _updateAngles(pose);

    bool leftIsUp = leftAngle > upThreshold;
    bool rightIsUp = rightAngle > upThreshold;
    
    bool leftIsDown = leftAngle < downThreshold;
    bool rightIsDown = rightAngle < downThreshold;

    if (stage == "down") {
      if (leftIsUp && rightIsUp) {
        stage = "holding";
        holdStart = DateTime.now();
      }
    } else if (stage == "holding") {
      if (leftAngle < upThreshold - 20 || rightAngle < upThreshold - 20) {
        stage = "down";
        holdStart = null;
      } else if (DateTime.now().difference(holdStart!) >= holdDuration) {
        stage = "up_done";
      }
    } else if (stage == "up_done") {
      if (leftIsDown && rightIsDown) {
        stage = "down";
        holdStart = null;
        reps++;
      }
    }
  }

  void _updateAngles(Pose pose) {
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final lElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rElbow = pose.landmarks[PoseLandmarkType.rightElbow];

    if (lHip != null && lShoulder != null && lElbow != null) {
      final rawL = _calculateAngle(lHip.x, lHip.y, lShoulder.x, lShoulder.y, lElbow.x, lElbow.y);
      _leftSmoothed = (_leftSmoothed == 0) ? rawL : (_leftSmoothed * smoothFactor) + (rawL * (1 - smoothFactor));
      leftAngle = _leftSmoothed;
    }

    if (rHip != null && rShoulder != null && rElbow != null) {
      final rawR = _calculateAngle(rHip.x, rHip.y, rShoulder.x, rShoulder.y, rElbow.x, rElbow.y);
      _rightSmoothed = (_rightSmoothed == 0) ? rawR : (_rightSmoothed * smoothFactor) + (rawR * (1 - smoothFactor));
      rightAngle = _rightSmoothed;
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
