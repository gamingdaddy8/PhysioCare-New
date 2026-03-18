import 'dart:math';
import 'unified_pose.dart';

class UnifiedPoseUtils {
  static UnifiedLandmark? lm(UnifiedPose pose, int idx) {
    if (idx < 0 || idx >= pose.landmarks.length) return null;
    return pose.landmarks[idx];
  }

  static double angleFrom3(UnifiedLandmark a, UnifiedLandmark b, UnifiedLandmark c) {
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

  static bool visible(UnifiedLandmark? lm, {double min = 0.3}) {
    if (lm == null) return false;
    return lm.visibility >= min;
  }
}
