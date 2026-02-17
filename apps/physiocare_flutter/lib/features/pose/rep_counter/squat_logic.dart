import 'dart:math';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class SquatLogic {
  int reps = 0;

  // Simple state machine:
  // standing -> down -> standing = 1 rep
  bool _isDown = false;

  // Tunable thresholds (degrees)
  // Knee angle: ~170 standing, ~70-100 squat depth
  final double downThreshold;
  final double upThreshold;

  // Basic debouncing
  DateTime _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration repCooldown;

  SquatLogic({
    this.downThreshold = 110,
    this.upThreshold = 160,
    this.repCooldown = const Duration(milliseconds: 700),
  });

  void reset() {
    reps = 0;
    _isDown = false;
    _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Returns feedback string (optional)
  String? update(Pose pose) {
    // Use LEFT leg primarily; if missing use RIGHT
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    double? kneeAngle;

    if (leftHip != null && leftKnee != null && leftAnkle != null) {
      kneeAngle = _angle(leftHip, leftKnee, leftAnkle);
    } else if (rightHip != null && rightKnee != null && rightAnkle != null) {
      kneeAngle = _angle(rightHip, rightKnee, rightAnkle);
    } else {
      return "Make sure your full leg is visible";
    }

    // Rep state machine
    if (!_isDown && kneeAngle < downThreshold) {
      _isDown = true;
      return "Good! Now stand up";
    }

    if (_isDown && kneeAngle > upThreshold) {
      final now = DateTime.now();
      if (now.difference(_lastRepTime) >= repCooldown) {
        reps += 1;
        _lastRepTime = now;
      }
      _isDown = false;
      return "Nice rep! Keep going";
    }

    // Form feedback (very light)
    if (!_isDown && kneeAngle < 140) {
      return "Go a bit lower";
    }

    if (_isDown && kneeAngle < 70) {
      return "Don't go too low";
    }

    return null;
  }

  double _angle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final abx = a.x - b.x;
    final aby = a.y - b.y;
    final cbx = c.x - b.x;
    final cby = c.y - b.y;

    final dot = abx * cbx + aby * cby;
    final magAB = sqrt(abx * abx + aby * aby);
    final magCB = sqrt(cbx * cbx + cby * cby);

    if (magAB == 0 || magCB == 0) return 180;

    final cosAngle = (dot / (magAB * magCB)).clamp(-1.0, 1.0);
    final angleRad = acos(cosAngle);
    return angleRad * (180 / pi);
  }
}
