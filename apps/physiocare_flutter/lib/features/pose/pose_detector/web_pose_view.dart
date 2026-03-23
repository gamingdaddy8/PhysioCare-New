import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'exercise_type.dart';
import 'web_mediapipe_bridge.dart';
import 'web_camera_preview.dart';
import 'unified_pose.dart';
import 'unified_pose_painter.dart';
import 'unified_pose_utils.dart';
import 'web_bicep_curl_logic.dart';
import 'web_side_raise_logic.dart';
import 'web_squat_logic.dart';

class WebPoseView extends StatefulWidget {
  const WebPoseView({
    super.key,
    this.initialExercise = ExerciseType.bicepCurl,
    this.onRepCompleted,
    this.onAccuracyUpdated,
  });

  final ExerciseType initialExercise;

  /// Called every time a rep is completed. Passes the total rep count.
  final ValueChanged<int>? onRepCompleted;

  /// Called periodically with the live session accuracy (0-100).
  final ValueChanged<double>? onAccuracyUpdated;

  @override
  State<WebPoseView> createState() => _WebPoseViewState();
}

class _WebPoseViewState extends State<WebPoseView> {
  late ExerciseType _selectedExercise;

  final WebBicepCurlLogic _bicepCounter = WebBicepCurlLogic();
  final WebSideRaiseLogic _sideRaiseLogic = WebSideRaiseLogic();
  final WebSquatLogic _squatLogic = WebSquatLogic();

  UnifiedPose? _lastPose;
  String _feedback = 'Waiting for pose...';

  double _liveAccuracy = 0;
  double _sessionAccuracySum = 0;
  int _sessionAccuracyCount = 0;
  int _prevTotalReps = 0;

  DateTime _lastFeedbackTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _feedbackCooldown = const Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    _selectedExercise = widget.initialExercise;

    if (!kIsWeb) return;

    WebMediapipeBridge.init((landmarks) {
      if (!mounted) return;

      final list = landmarks
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(
            (m) => UnifiedLandmark(
              x: (m['x'] ?? 0).toDouble(),
              y: (m['y'] ?? 0).toDouble(),
              z: (m['z'] ?? 0).toDouble(),
              visibility: (m['visibility'] ?? 1).toDouble(),
            ),
          )
          .toList();

      final pose = UnifiedPose(list);
      setState(() => _lastPose = pose);

      _updateLogic(pose);
      _updateAccuracy(pose);
      _updateFeedback();
      _notifyRepCallback();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      startMediapipePose('mp-video');
    });
  }

  @override
  void dispose() {
    if (kIsWeb) stopMediapipePose();
    super.dispose();
  }

  void _updateLogic(UnifiedPose pose) {
    String? msg;
    if (_selectedExercise == ExerciseType.bicepCurl) {
      msg = _bicepCounter.update(pose);
    } else if (_selectedExercise == ExerciseType.sideRaise) {
      msg = _sideRaiseLogic.update(pose);
    } else if (_selectedExercise == ExerciseType.squats) {
      msg = _squatLogic.update(pose);
    }

    if (msg != null && msg.trim().isNotEmpty) {
      final now = DateTime.now();
      if (now.difference(_lastFeedbackTime) >= _feedbackCooldown) {
        _lastFeedbackTime = now;
        setState(() => _feedback = msg!);
      }
    }
  }

  void _updateFeedback() {
    if (_lastPose == null) return;
    if (_feedback == 'Waiting for pose...') {
      setState(() => _feedback = 'Pose detected ✅ Start moving');
    }
  }

  int _currentReps() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.reps;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.reps;
      case ExerciseType.squats:
        return _squatLogic.reps;
    }
  }

  /// Fire onRepCompleted whenever total reps increases
  void _notifyRepCallback() {
    if (widget.onRepCompleted == null) return;
    final current = _currentReps();
    if (current > _prevTotalReps) {
      _prevTotalReps = current;
      widget.onRepCompleted!(current);
    }
  }

  void _reset() {
    setState(() {
      _prevTotalReps = 0;
      _bicepCounter.reset();
      _sideRaiseLogic.reset();
      _squatLogic.reset();
    });
  }

  double _computeLiveAccuracy(UnifiedPose pose) {
    if (_selectedExercise == ExerciseType.bicepCurl) {
      final s = UnifiedPoseUtils.lm(pose, 11);
      final e = UnifiedPoseUtils.lm(pose, 13);
      final w = UnifiedPoseUtils.lm(pose, 15);
      if (!UnifiedPoseUtils.visible(s) ||
          !UnifiedPoseUtils.visible(e) ||
          !UnifiedPoseUtils.visible(w)) {
        return 0;
      }
      final angle = UnifiedPoseUtils.angleFrom3(s!, e!, w!);
      final target = (_bicepCounter.reps % 2 == 0) ? 45.0 : 165.0;
      return (100 - (angle - target).abs() * 1.2).clamp(0, 100);
    }
    if (_selectedExercise == ExerciseType.sideRaise) {
      final hip = UnifiedPoseUtils.lm(pose, 23);
      final sh = UnifiedPoseUtils.lm(pose, 11);
      final el = UnifiedPoseUtils.lm(pose, 13);
      if (!UnifiedPoseUtils.visible(hip) ||
          !UnifiedPoseUtils.visible(sh) ||
          !UnifiedPoseUtils.visible(el)) {
        return 0;
      }
      final angle = UnifiedPoseUtils.angleFrom3(hip!, sh!, el!);
      final target = (_sideRaiseLogic.reps % 2 == 0) ? 90.0 : 15.0;
      return (100 - (angle - target).abs()).clamp(0, 100);
    }
    if (_selectedExercise == ExerciseType.squats) {
      final hip = UnifiedPoseUtils.lm(pose, 23);
      final knee = UnifiedPoseUtils.lm(pose, 25);
      final ankle = UnifiedPoseUtils.lm(pose, 27);
      if (!UnifiedPoseUtils.visible(hip) ||
          !UnifiedPoseUtils.visible(knee) ||
          !UnifiedPoseUtils.visible(ankle)) {
        return 0;
      }
      final angle = UnifiedPoseUtils.angleFrom3(hip!, knee!, ankle!);
      final target = (_squatLogic.reps % 2 == 0) ? 95.0 : 170.0;
      return (100 - (angle - target).abs() * 0.9).clamp(0, 100);
    }
    return 0;
  }

  void _updateAccuracy(UnifiedPose pose) {
    final live = _computeLiveAccuracy(pose);
    _liveAccuracy = (_liveAccuracy * 0.85) + (live * 0.15);
    _sessionAccuracySum += live;
    _sessionAccuracyCount += 1;

    // Fire accuracy callback every ~10 frames
    if (_sessionAccuracyCount % 10 == 0) {
      widget.onAccuracyUpdated?.call(_sessionAccuracyAvg);
    }
  }

  double get _sessionAccuracyAvg => _sessionAccuracyCount == 0
      ? 0
      : _sessionAccuracySum / _sessionAccuracyCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const WebCameraPreview(viewId: 'mp-video'),

          if (_lastPose != null)
            CustomPaint(
              painter: UnifiedPosePainter(
                pose: _lastPose!,
                sourceSize: const Size(640, 480),
                isNormalized: true,
              ),
            ),

          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                'Reps: ${_currentReps()}\n'
                'Acc: ${_liveAccuracy.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black54,
              child: Text(
                '$_feedback   |   Avg: ${_sessionAccuracyAvg.toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
