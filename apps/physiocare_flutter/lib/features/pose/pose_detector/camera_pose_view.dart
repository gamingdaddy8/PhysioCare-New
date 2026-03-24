import 'dart:ui';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../rep_counter/bicep_curl_counter.dart';
import '../rep_counter/side_raise_logic.dart';
import '../rep_counter/squat_logic.dart';
import '../rep_counter/hip_abduction_logic.dart';
import '../rep_counter/knee_extension_logic.dart';
import 'exercise_type.dart';
import 'mlkit_pose_service.dart';
import 'pose_painter.dart';

class CameraPoseView extends StatefulWidget {
  const CameraPoseView({
    super.key,
    this.showOverlayUI = true,
    this.initialExercise = ExerciseType.bicepCurl,
    this.onExerciseChanged,
    this.onRepCompleted,
    this.onAccuracyUpdated,
  });

  final bool showOverlayUI;
  final ExerciseType initialExercise;
  final ValueChanged<ExerciseType>? onExerciseChanged;

  /// Called every time a rep is completed. Passes the total rep count.
  final ValueChanged<int>? onRepCompleted;

  /// Called periodically with the live session accuracy (0-100).
  final ValueChanged<double>? onAccuracyUpdated;

  @override
  State<CameraPoseView> createState() => _CameraPoseViewState();
}

class _CameraPoseViewState extends State<CameraPoseView> {
  CameraController? _cameraController;
  late final MLKitPoseService _poseService;

  bool _isBusy = false;
  bool _isStreaming = false;

  String _status = 'Initializing...';
  Pose? _lastPose;

  String _feedbackText = 'Get into position...';
  Color  _feedbackColor = Colors.white;

  double _liveAccuracy        = 0;
  double _sessionAccuracySum  = 0;
  int    _sessionAccuracyCount = 0;

  DateTime _lastFeedbackTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _feedbackCooldown = const Duration(milliseconds: 800);

  DateTime _lastPoseUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _poseUiCooldown = const Duration(milliseconds: 120);

  late ExerciseType _selectedExercise = widget.initialExercise;

  final BicepCurlCounter _bicepCounter  = BicepCurlCounter();
  final SideRaiseLogic   _sideRaiseLogic = SideRaiseLogic();
  final SquatLogic       _squatLogic    = SquatLogic();
  final HipAbductionLogic _hipAbductionLogic = HipAbductionLogic();
  final KneeExtensionLogic _kneeExtensionLogic = KneeExtensionLogic();

  // Track previous rep counts to detect new reps
  int _prevTotalReps = 0;

  @override
  void initState() {
    super.initState();
    _poseService = MLKitPoseService();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() => _status = 'Camera started ✅');
      _isStreaming = true;

      await _cameraController!.startImageStream((CameraImage image) async {
        if (!_isStreaming || _isBusy) return;
        _isBusy = true;

        try {
          final inputImage = _inputImageFromCameraImage(image);
          final poses = await _poseService.processImage(inputImage);
          if (!mounted) return;

          if (poses.isNotEmpty) {
            final pose = poses.first;
            _lastPose = pose;
            _updateAccuracy(pose);
            _updateExerciseLogic(pose);
            _updateFeedback();
            _notifyRepCallback();

            final now = DateTime.now();
            if (now.difference(_lastPoseUiUpdate) > _poseUiCooldown) {
              _lastPoseUiUpdate = now;
              setState(() {
                if (_status != 'Pose detected ✅') _status = 'Pose detected ✅';
              });
            }
          } else {
            if (_status != 'No pose detected...') {
              setState(() {
                _status   = 'No pose detected...';
                _lastPose = null;
              });
            } else {
              _lastPose = null;
            }
          }
        } catch (e) {
          if (mounted) setState(() => _status = 'Error: $e');
        } finally {
          _isBusy = false;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'Camera init failed: $e');
    }
  }

  InputImage _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameraController!.description;
    final rotation = InputImageRotationValue.fromRawValue(
          camera.sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;
    if (format != InputImageFormat.nv21) {
      throw Exception('Image format is not NV21 (found: $format)');
    }
    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void _updateExerciseLogic(Pose pose) {
    if (_selectedExercise == ExerciseType.bicepCurl) {
      _bicepCounter.update(pose);
    } else if (_selectedExercise == ExerciseType.sideRaise) {
      _sideRaiseLogic.update(pose);
    } else if (_selectedExercise == ExerciseType.squats) {
      _squatLogic.update(pose);
    } else if (_selectedExercise == ExerciseType.standingHipAbduction) {
      _hipAbductionLogic.update(pose);
    } else if (_selectedExercise == ExerciseType.seatedKneeExtension) {
      _kneeExtensionLogic.update(pose);
    }
  }

  /// Fire onRepCompleted whenever total reps increases
  void _notifyRepCallback() {
    if (widget.onRepCompleted == null) return;
    final current = _totalReps();
    if (current > _prevTotalReps) {
      _prevTotalReps = current;
      widget.onRepCompleted!(current);
    }
  }

  int _totalReps() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.leftReps + _bicepCounter.rightReps;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.leftReps + _sideRaiseLogic.rightReps;
      case ExerciseType.squats:
        return _squatLogic.reps;
      case ExerciseType.standingHipAbduction:
        return _hipAbductionLogic.leftReps + _hipAbductionLogic.rightReps;
      case ExerciseType.seatedKneeExtension:
        return _kneeExtensionLogic.leftReps + _kneeExtensionLogic.rightReps;
    }
  }

  void _resetExercise() {
    setState(() {
      _liveAccuracy        = 0;
      _sessionAccuracySum  = 0;
      _sessionAccuracyCount = 0;
      _prevTotalReps       = 0;
      _bicepCounter.reset();
      _sideRaiseLogic.reset();
      _squatLogic.reset();
      _hipAbductionLogic.reset();
      _kneeExtensionLogic.reset();
    });
  }

  Future<void> _stopCamera() async {
    try {
      _isStreaming = false;
      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopCamera();
    _cameraController?.dispose();
    _poseService.dispose();
    super.dispose();
  }

  void _updateFeedback() {
    final now = DateTime.now();
    if (now.difference(_lastFeedbackTime) < _feedbackCooldown) return;
    _lastFeedbackTime = now;

    String msg   = '';
    Color  color = Colors.white;

    if (_lastPose == null) {
      msg   = 'No pose detected...';
      color = Colors.orangeAccent;
    } else if (_selectedExercise == ExerciseType.bicepCurl) {
      final l = _bicepCounter.leftAngle;
      final r = _bicepCounter.rightAngle;
      if (l == 0 && r == 0) {
        msg = 'Bring arms into view'; color = Colors.orangeAccent;
      } else if (l < 70 || r < 70) {
        msg = 'Good! Curl up fully 💪'; color = Colors.greenAccent;
      } else if (l > 150 && r > 150) {
        msg = 'Now curl up'; color = Colors.white;
      } else {
        msg = 'Control the movement'; color = Colors.white70;
      }
    } else if (_selectedExercise == ExerciseType.sideRaise) {
      final l = _sideRaiseLogic.leftAngle;
      final r = _sideRaiseLogic.rightAngle;
      if (l == 0 && r == 0) {
        msg = 'Stand in frame with arms visible'; color = Colors.orangeAccent;
      } else if (l > 75 || r > 75) {
        msg = 'Great! Hold at shoulder height 🔥'; color = Colors.greenAccent;
      } else if (l < 30 && r < 30) {
        msg = 'Raise your arms sideways'; color = Colors.white;
      } else {
        msg = 'Lift higher (towards 90°)'; color = Colors.white70;
      }
    } else if (_selectedExercise == ExerciseType.standingHipAbduction) {
      final l = _hipAbductionLogic.leftAngle;
      final r = _hipAbductionLogic.rightAngle;
      if (l == 0 && r == 0) {
        msg = 'Stand in frame with legs visible'; color = Colors.orangeAccent;
      } else if (l < 155 || r < 155) {
        msg = 'Good! Hold it out 🔥'; color = Colors.greenAccent;
      } else {
        msg = 'Lift leg sideways out'; color = Colors.white;
      }
    } else if (_selectedExercise == ExerciseType.seatedKneeExtension) {
      final l = _kneeExtensionLogic.leftAngle;
      final r = _kneeExtensionLogic.rightAngle;
      if (l == 0 && r == 0) {
        msg = 'Ensure legs are fully visible'; color = Colors.orangeAccent;
      } else if (l > 165 || r > 165) {
        msg = 'Great! Hold it straight 🔥'; color = Colors.greenAccent;
      } else {
        msg = 'Extend your knee straight'; color = Colors.white;
      }
    }

    if (msg != _feedbackText) {
      setState(() {
        _feedbackText  = msg;
        _feedbackColor = color;
      });
    }
  }

  double _computeLiveAccuracy(Pose pose) {
    if (_selectedExercise == ExerciseType.bicepCurl) {
      final left  = _bicepCounter.leftAngle;
      final right = _bicepCounter.rightAngle;
      double scoreFor(double angle) {
        final target = angle < 100 ? 45.0 : 165.0;
        return (100 - (angle - target).abs() * 1.2).clamp(0, 100);
      }
      final scores = <double>[
        if (left  > 0) scoreFor(left),
        if (right > 0) scoreFor(right),
      ];
      if (scores.isEmpty) return 0;
      return scores.reduce((a, b) => a + b) / scores.length;
    }
    if (_selectedExercise == ExerciseType.sideRaise) {
      final left  = _sideRaiseLogic.leftAngle;
      final right = _sideRaiseLogic.rightAngle;
      double scoreFor(double angle) {
        final target = angle > 45 ? 90.0 : 15.0;
        return (100 - (angle - target).abs()).clamp(0, 100);
      }
      final scores = <double>[
        if (left  > 0) scoreFor(left),
        if (right > 0) scoreFor(right),
      ];
      if (scores.isEmpty) return 0;
      return scores.reduce((a, b) => a + b) / scores.length;
    }
    if (_selectedExercise == ExerciseType.squats) {
      final lh = pose.landmarks[PoseLandmarkType.leftHip];
      final lk = pose.landmarks[PoseLandmarkType.leftKnee];
      final la = pose.landmarks[PoseLandmarkType.leftAnkle];
      final rh = pose.landmarks[PoseLandmarkType.rightHip];
      final rk = pose.landmarks[PoseLandmarkType.rightKnee];
      final ra = pose.landmarks[PoseLandmarkType.rightAnkle];
      double? kneeAngle;
      if (lh != null && lk != null && la != null) {
        kneeAngle = _angle3(lh, lk, la);
      } else if (rh != null && rk != null && ra != null) {
        kneeAngle = _angle3(rh, rk, ra);
      }
      if (kneeAngle == null) return 0;
      final target = kneeAngle < 140 ? 95.0 : 170.0;
      return (100 - (kneeAngle - target).abs() * 0.9).clamp(0, 100);
    }
    if (_selectedExercise == ExerciseType.standingHipAbduction) {
      final left  = _hipAbductionLogic.leftAngle;
      final right = _hipAbductionLogic.rightAngle;
      double scoreFor(double angle) {
        final target = angle > 160 ? 175.0 : 135.0;
        return (100 - (angle - target).abs()).clamp(0, 100);
      }
      final scores = <double>[
        if (left  > 0) scoreFor(left),
        if (right > 0) scoreFor(right),
      ];
      if (scores.isEmpty) return 0;
      return scores.reduce((a, b) => a + b) / scores.length;
    }
    if (_selectedExercise == ExerciseType.seatedKneeExtension) {
      final left  = _kneeExtensionLogic.leftAngle;
      final right = _kneeExtensionLogic.rightAngle;
      double scoreFor(double angle) {
        final target = angle > 140 ? 180.0 : 90.0;
        return (100 - (angle - target).abs() * 0.9).clamp(0, 100);
      }
      final scores = <double>[
        if (left  > 0) scoreFor(left),
        if (right > 0) scoreFor(right),
      ];
      if (scores.isEmpty) return 0;
      return scores.reduce((a, b) => a + b) / scores.length;
    }
    return 0;
  }

  double _angle3(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final abx = a.x - b.x, aby = a.y - b.y;
    final cbx = c.x - b.x, cby = c.y - b.y;
    final dot   = abx * cbx + aby * cby;
    final magAB = sqrt(abx * abx + aby * aby);
    final magCB = sqrt(cbx * cbx + cby * cby);
    if (magAB == 0 || magCB == 0) return 180;
    return acos((dot / (magAB * magCB)).clamp(-1.0, 1.0)) * (180 / pi);
  }

  void _updateAccuracy(Pose pose) {
    final live = _computeLiveAccuracy(pose);
    _liveAccuracy        = (_liveAccuracy * 0.85) + (live * 0.15);
    _sessionAccuracySum  += live;
    _sessionAccuracyCount += 1;

    // Fire accuracy callback every ~10 frames to avoid overwhelming
    if (_sessionAccuracyCount % 10 == 0) {
      widget.onAccuracyUpdated?.call(_sessionAccuracyAvg);
    }
  }

  double get _sessionAccuracyAvg =>
      _sessionAccuracyCount == 0 ? 0 : _sessionAccuracySum / _sessionAccuracyCount;

  int _leftReps() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl: return _bicepCounter.leftReps;
      case ExerciseType.sideRaise: return _sideRaiseLogic.leftReps;
      case ExerciseType.squats:    return _squatLogic.reps;
      case ExerciseType.standingHipAbduction: return _hipAbductionLogic.leftReps;
      case ExerciseType.seatedKneeExtension: return _kneeExtensionLogic.leftReps;
    }
  }

  int _rightReps() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl: return _bicepCounter.rightReps;
      case ExerciseType.sideRaise: return _sideRaiseLogic.rightReps;
      case ExerciseType.squats:    return _squatLogic.reps;
      case ExerciseType.standingHipAbduction: return _hipAbductionLogic.rightReps;
      case ExerciseType.seatedKneeExtension: return _kneeExtensionLogic.rightReps;
    }
  }

  double _leftAngle() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl: return _bicepCounter.leftAngle;
      case ExerciseType.sideRaise: return _sideRaiseLogic.leftAngle;
      case ExerciseType.squats:    return 0;
      case ExerciseType.standingHipAbduction: return _hipAbductionLogic.leftAngle;
      case ExerciseType.seatedKneeExtension: return _kneeExtensionLogic.leftAngle;
    }
  }

  double _rightAngle() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl: return _bicepCounter.rightAngle;
      case ExerciseType.sideRaise: return _sideRaiseLogic.rightAngle;
      case ExerciseType.squats:    return 0;
      case ExerciseType.standingHipAbduction: return _hipAbductionLogic.rightAngle;
      case ExerciseType.seatedKneeExtension: return _kneeExtensionLogic.rightAngle;
    }
  }

  String _leftStage() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl: return _bicepCounter.leftStage;
      case ExerciseType.sideRaise: return _sideRaiseLogic.leftStage;
      case ExerciseType.squats:    return _squatLogic.reps > 0 ? 'Counting' : 'Ready';
      case ExerciseType.standingHipAbduction: return _hipAbductionLogic.leftStage;
      case ExerciseType.seatedKneeExtension: return _kneeExtensionLogic.leftStage;
    }
  }

  String _rightStage() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl: return _bicepCounter.rightStage;
      case ExerciseType.sideRaise: return _sideRaiseLogic.rightStage;
      case ExerciseType.squats:    return _squatLogic.reps > 0 ? 'Counting' : 'Ready';
      case ExerciseType.standingHipAbduction: return _hipAbductionLogic.rightStage;
      case ExerciseType.seatedKneeExtension: return _kneeExtensionLogic.rightStage;
    }
  }

  String _exerciseTitle() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl: return 'Bicep Curl';
      case ExerciseType.sideRaise: return 'Side Raise';
      case ExerciseType.squats:    return 'Squats';
      case ExerciseType.standingHipAbduction: return 'Standing Hip Abduction';
      case ExerciseType.seatedKneeExtension: return 'Seated Knee Extension';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: Colors.black,
        child: controller != null && controller.value.isInitialized
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),

                  if (_lastPose != null)
                    CustomPaint(
                      painter: PosePainter(
                        pose: _lastPose!,
                        imageSize: Size(
                          controller.value.previewSize!.height,
                          controller.value.previewSize!.width,
                        ),
                        isFrontCamera: controller.description.lensDirection ==
                            CameraLensDirection.front,
                      ),
                    ),

                  if (widget.showOverlayUI)
                    Positioned(
                      top: 16, left: 16, right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Text('Exercise: ',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14)),
                              const SizedBox(width: 10),
                              Text(
                                _exerciseTitle(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Reset reps',
                                onPressed: _resetExercise,
                                icon: const Icon(Icons.restart_alt,
                                    color: Colors.white),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                _feedbackText,
                                style: TextStyle(
                                    color: _feedbackColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Left: ${_leftReps()}  Right: ${_rightReps()}  Total: ${_totalReps()}\n'
                              'Live Acc: ${_liveAccuracy.toStringAsFixed(0)}%  Avg: ${_sessionAccuracyAvg.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'L Angle: ${_leftAngle().toStringAsFixed(1)}°  |  R Angle: ${_rightAngle().toStringAsFixed(1)}°',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'L: ${_leftStage()}  |  R: ${_rightStage()}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            Text(_status,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}