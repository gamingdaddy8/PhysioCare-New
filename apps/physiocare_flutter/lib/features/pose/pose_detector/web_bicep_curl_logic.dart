import 'unified_pose.dart';
import 'unified_pose_utils.dart';

class WebBicepCurlLogic {
  int reps = 0;
  String _leftStage = "down";
  String _rightStage = "down";

  DateTime? _leftHoldStart;
  DateTime? _rightHoldStart;

  final double upThreshold;
  final double downThreshold;
  final Duration holdDuration = const Duration(seconds: 3);

  WebBicepCurlLogic({
    this.upThreshold = 55,
    this.downThreshold = 155,
  });

  void reset() {
    reps = 0;
    _leftStage = "down";
    _rightStage = "down";
    _leftHoldStart = null;
    _rightHoldStart = null;
  }

  String? update(UnifiedPose pose) {
    String? msg;
    bool repTriggered = false;

    // Left Arm
    final ls = UnifiedPoseUtils.lm(pose, 11);
    final le = UnifiedPoseUtils.lm(pose, 13);
    final lw = UnifiedPoseUtils.lm(pose, 15);

    if (UnifiedPoseUtils.visible(ls) && UnifiedPoseUtils.visible(le) && UnifiedPoseUtils.visible(lw)) {
      final angle = UnifiedPoseUtils.angleFrom3(ls!, le!, lw!);
      bool isUp = angle < upThreshold;
      bool isDown = angle > downThreshold;

      if (isDown) {
        if (_leftStage == "up_done") {
          repTriggered = true;
          msg = "Nice rep!";
        }
        _leftStage = "down";
        _leftHoldStart = null;
      } else if (isUp) {
        if (_leftStage == "down") {
          _leftStage = "holding";
          _leftHoldStart = DateTime.now();
          msg = "Hold it...";
        } else if (_leftStage == "holding") {
          final diff = DateTime.now().difference(_leftHoldStart!).inSeconds;
          if (diff >= holdDuration.inSeconds) {
            _leftStage = "up_done";
            msg = "Great! Now lower slowly";
          } else {
            msg = "Hold... ${3 - diff}";
          }
        }
      } else {
        if (_leftStage == "holding" && angle > upThreshold + 25) {
          _leftStage = "down";
          _leftHoldStart = null;
          msg = "Dropped early!";
        } else if (_leftStage == "down" && angle < 90 && msg == null) {
          msg = "Curl higher";
        }
      }
    }

    // Right Arm
    final rs = UnifiedPoseUtils.lm(pose, 12);
    final re = UnifiedPoseUtils.lm(pose, 14);
    final rw = UnifiedPoseUtils.lm(pose, 16);

    if (UnifiedPoseUtils.visible(rs) && UnifiedPoseUtils.visible(re) && UnifiedPoseUtils.visible(rw)) {
      final angle = UnifiedPoseUtils.angleFrom3(rs!, re!, rw!);
      bool isUp = angle < upThreshold;
      bool isDown = angle > downThreshold;

      if (isDown) {
        if (_rightStage == "up_done") {
          repTriggered = true;
          if (msg == null) msg = "Nice rep!";
        }
        _rightStage = "down";
        _rightHoldStart = null;
      } else if (isUp) {
        if (_rightStage == "down") {
          _rightStage = "holding";
          _rightHoldStart = DateTime.now();
          if (msg == null) msg = "Hold it...";
        } else if (_rightStage == "holding") {
          final diff = DateTime.now().difference(_rightHoldStart!).inSeconds;
          if (diff >= holdDuration.inSeconds) {
            _rightStage = "up_done";
            if (msg == null) msg = "Great! Now lower slowly";
          } else {
            if (msg == null) msg = "Hold... ${3 - diff}";
          }
        }
      } else {
        if (_rightStage == "holding" && angle > upThreshold + 25) {
          _rightStage = "down";
          _rightHoldStart = null;
          if (msg == null) msg = "Dropped early!";
        } else if (_rightStage == "down" && angle < 90 && msg == null) {
          msg = "Curl higher";
        }
      }
    }

    if (repTriggered) reps += 1;

    if (msg == null && 
       (!UnifiedPoseUtils.visible(ls) || !UnifiedPoseUtils.visible(le) || !UnifiedPoseUtils.visible(lw)) &&
       (!UnifiedPoseUtils.visible(rs) || !UnifiedPoseUtils.visible(re) || !UnifiedPoseUtils.visible(rw))) {
      return "Keep your arms visible";
    }

    return msg;
  }
}
