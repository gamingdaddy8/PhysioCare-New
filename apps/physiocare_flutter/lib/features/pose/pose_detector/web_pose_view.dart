import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'web_mediapipe_bridge.dart';
import 'web_camera_preview.dart';
import 'unified_pose.dart';
import 'unified_pose_painter.dart';
import 'unified_pose_utils.dart';
import 'web_bicep_curl_logic.dart';
import 'web_side_raise_logic.dart';
import 'web_squat_logic.dart';

enum ExerciseType {
  bicepCurl,
  sideRaise,
  squats,
}

class WebPoseView extends StatefulWidget {
  const WebPoseView({super.key});

  @override
  State<WebPoseView> createState() => _WebPoseViewState();
}

class _WebPoseViewState extends State<WebPoseView> {
  ExerciseType _selectedExercise = ExerciseType.bicepCurl;

  final WebBicepCurlLogic _bicepCounter = WebBicepCurlLogic();
  final WebSideRaiseLogic _sideRaiseLogic = WebSideRaiseLogic();
  final WebSquatLogic _squatLogic = WebSquatLogic();

  UnifiedPose? _lastPose;

  String _feedback = "Waiting for pose...";

  double _liveAccuracy = 0;
  double _sessionAccuracySum = 0;
  int _sessionAccuracyCount = 0;
  DateTime _lastFeedbackTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _feedbackCooldown = const Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) return;

    WebMediapipeBridge.init((landmarks) {
      if (!mounted) return;

      // landmarks is a List of 33 maps: {x,y,z,visibility}
      final list = landmarks
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(
            (m) => UnifiedLandmark(
              x: (m["x"] ?? 0).toDouble(),
              y: (m["y"] ?? 0).toDouble(),
              z: (m["z"] ?? 0).toDouble(),
              visibility: (m["visibility"] ?? 1).toDouble(),
            ),
          )
          .toList();

      final pose = UnifiedPose(list);

      setState(() => _lastPose = pose);

      _updateLogic(pose);
      _updateAccuracy(pose);
      _updateFeedback();
    });

    startMediapipePose('mp-video');
  }

  @override
  void dispose() {
    if (kIsWeb) {
      stopMediapipePose();
    }
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

    // If no feedback has been set yet, show a default
    if (_feedback == "Waiting for pose...") {
      setState(() => _feedback = "Pose detected ✅ Start moving");
    }
  }

  String _exerciseName() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return "Bicep Curl";
      case ExerciseType.sideRaise:
        return "Side Raise";
      case ExerciseType.squats:
        return "Squats";
    }
  }

  void _reset() {
    _bicepCounter.reset();
    _sideRaiseLogic.reset();
    _squatLogic.reset();
  }

    double _computeLiveAccuracy(UnifiedPose pose) {
    // Simple angle-based scoring (0..100)
    double score = 0;

    if (_selectedExercise == ExerciseType.bicepCurl) {
      final s = UnifiedPoseUtils.lm(pose, 11);
      final e = UnifiedPoseUtils.lm(pose, 13);
      final w = UnifiedPoseUtils.lm(pose, 15);
      if (!UnifiedPoseUtils.visible(s) || !UnifiedPoseUtils.visible(e) || !UnifiedPoseUtils.visible(w)) return 0;
      final angle = UnifiedPoseUtils.angleFrom3(s!, e!, w!);

      // Ideal "up" angle ~45, ideal "down" ~165
      // We'll score based on closeness to either end depending on stage.
      final target = (_bicepCounter.reps % 2 == 0) ? 45.0 : 165.0;
      final diff = (angle - target).abs();
      score = (100 - diff * 1.2).clamp(0, 100);
    } else if (_selectedExercise == ExerciseType.sideRaise) {
      final hip = UnifiedPoseUtils.lm(pose, 23);
      final sh = UnifiedPoseUtils.lm(pose, 11);
      final el = UnifiedPoseUtils.lm(pose, 13);
      if (!UnifiedPoseUtils.visible(hip) || !UnifiedPoseUtils.visible(sh) || !UnifiedPoseUtils.visible(el)) return 0;
      final angle = UnifiedPoseUtils.angleFrom3(hip!, sh!, el!);

      // Ideal top ~90, bottom ~15
      final target = (_sideRaiseLogic.reps % 2 == 0) ? 90.0 : 15.0;
      final diff = (angle - target).abs();
      score = (100 - diff * 1.0).clamp(0, 100);
    } else if (_selectedExercise == ExerciseType.squats) {
      final hip = UnifiedPoseUtils.lm(pose, 23);
      final knee = UnifiedPoseUtils.lm(pose, 25);
      final ankle = UnifiedPoseUtils.lm(pose, 27);
      if (!UnifiedPoseUtils.visible(hip) || !UnifiedPoseUtils.visible(knee) || !UnifiedPoseUtils.visible(ankle)) return 0;
      final angle = UnifiedPoseUtils.angleFrom3(hip!, knee!, ankle!);

      // Ideal down ~95, up ~170
      final target = (_squatLogic.reps % 2 == 0) ? 95.0 : 170.0;
      final diff = (angle - target).abs();
      score = (100 - diff * 0.9).clamp(0, 100);
    }

    return score;
  }

  void _updateAccuracy(UnifiedPose pose) {
    final live = _computeLiveAccuracy(pose);

    // Smooth live accuracy
    _liveAccuracy = (_liveAccuracy * 0.85) + (live * 0.15);

    // Session average
    _sessionAccuracySum += live;
    _sessionAccuracyCount += 1;
  }

  double get _sessionAccuracyAvg {
    if (_sessionAccuracyCount == 0) return 0;
    return _sessionAccuracySum / _sessionAccuracyCount;
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

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        title: Text("Pose (Web) — ${_exerciseName()}"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<ExerciseType>(
                    value: _selectedExercise,
                    items: const [
                      DropdownMenuItem(
                        value: ExerciseType.bicepCurl,
                        child: Text("Bicep Curl"),
                      ),
                      DropdownMenuItem(
                        value: ExerciseType.sideRaise,
                        child: Text("Side Raise"),
                      ),
                      DropdownMenuItem(
                        value: ExerciseType.squats,
                        child: Text("Squats"),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedExercise = v);
                      _reset();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Web camera preview (real video)
                      const WebCameraPreview(viewId: 'mp-video'),

                      // Skeleton overlay
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            "Reps: ${_currentReps()}\nAcc: ${_liveAccuracy.toStringAsFixed(0)}%",
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
                            _feedback + "   |   Avg: ${_sessionAccuracyAvg.toStringAsFixed(0)}%",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
