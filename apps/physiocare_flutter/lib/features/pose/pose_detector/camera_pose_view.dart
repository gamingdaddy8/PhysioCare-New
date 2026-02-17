import 'dart:async';
import 'dart:ui';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../rep_counter/bicep_curl_counter.dart';
import '../rep_counter/side_raise_logic.dart';
import '../rep_counter/squat_logic.dart';

import 'mlkit_pose_service.dart';
import 'pose_painter.dart';

enum ExerciseType {
  bicepCurl,
  sideRaise,
  squats,
}

class CameraPoseView extends StatefulWidget {
  const CameraPoseView({
    super.key,
    this.showOverlayUI = true,
    this.initialExercise = ExerciseType.bicepCurl,
    this.onExerciseChanged,
  });

  /// If false, only camera + skeleton will be shown.
  final bool showOverlayUI;

  /// Preselect exercise when opening this view.
  final ExerciseType initialExercise;

  /// Optional callback when exercise changes from dropdown.
  final ValueChanged<ExerciseType>? onExerciseChanged;

  @override
  State<CameraPoseView> createState() => _CameraPoseViewState();
}

class _CameraPoseViewState extends State<CameraPoseView> {
  CameraController? _cameraController;
  late final MLKitPoseService _poseService;

  bool _isBusy = false;
  bool _isStreaming = false;

  String _status = "Initializing...";
  Pose? _lastPose;

  // ==========================
  // Feedback System (TEXT)
  // ==========================
  String _feedbackText = "Get into position...";
  Color _feedbackColor = Colors.white;

  double _liveAccuracy = 0;
  double _sessionAccuracySum = 0;
  int _sessionAccuracyCount = 0;

  DateTime _lastFeedbackTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _feedbackCooldown = const Duration(milliseconds: 800);

  // ==========================
  // UI Throttling (reduce lag)
  // ==========================
  DateTime _lastPoseUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _poseUiCooldown = const Duration(milliseconds: 120);

  // ==========================
  // Exercise Selection
  // ==========================
  late ExerciseType _selectedExercise = widget.initialExercise;

  // ==========================
  // Exercise Logic Objects
  // ==========================
  final BicepCurlCounter _bicepCounter = BicepCurlCounter();
  final SideRaiseLogic _sideRaiseLogic = SideRaiseLogic();
  final SquatLogic _squatLogic = SquatLogic();

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

      setState(() {
        _status = "Camera started ✅";
      });

      _isStreaming = true;

      await _cameraController!.startImageStream((CameraImage image) async {
        if (!_isStreaming) return;
        if (_isBusy) return;

        _isBusy = true;

        try {
          final inputImage = _inputImageFromCameraImage(image);
          final poses = await _poseService.processImage(inputImage);

          if (!mounted) return;

          if (poses.isNotEmpty) {
            final pose = poses.first;

            // Keep latest pose for exercise logic
            _lastPose = pose;
            _updateAccuracy(pose);

            // ==========================
            // Update Selected Exercise Logic
            // ==========================
            if (_selectedExercise == ExerciseType.bicepCurl) {
              _bicepCounter.update(pose);
            } else if (_selectedExercise == ExerciseType.sideRaise) {
              _sideRaiseLogic.update(pose);
            } else if (_selectedExercise == ExerciseType.squats) {
              _squatLogic.update(pose);
            }

            // Feedback is throttled internally
            _updateFeedback();

            // ==========================
            // Throttle UI rebuilds
            // ==========================
            final now = DateTime.now();
            if (now.difference(_lastPoseUiUpdate) > _poseUiCooldown) {
              _lastPoseUiUpdate = now;

              // Update status only if changed
              if (_status != "Pose detected ✅") {
                setState(() {
                  _status = "Pose detected ✅";
                });
              } else {
                // Force repaint for skeleton at throttled rate
                setState(() {});
              }
            }
          } else {
            if (_status != "No pose detected...") {
              setState(() {
                _status = "No pose detected...";
                _lastPose = null;
              });
            } else {
              _lastPose = null;
            }
          }
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _status = "Error: $e";
          });
        } finally {
          _isBusy = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = "Camera init failed: $e";
      });
    }
  }

  // ==========================================
  // ML KIT INPUT IMAGE (NV21)
  // ==========================================
  InputImage _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameraController!.description;

    final rotation = InputImageRotationValue.fromRawValue(
          camera.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    if (format != InputImageFormat.nv21) {
      throw Exception("Image format is not NV21 (found: $format)");
    }

    final bytes = image.planes.first.bytes;

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
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

  void _resetExercise() {
    setState(() {
      _liveAccuracy = 0;
      _sessionAccuracySum = 0;
      _sessionAccuracyCount = 0;

      _bicepCounter.reset();
      _sideRaiseLogic.reset();
      _squatLogic.reset();
    });
  }

  @override
  void dispose() {
    _stopCamera();
    _cameraController?.dispose();
    _poseService.dispose();
    super.dispose();
  }

  // ==========================================
  // FEEDBACK SYSTEM (TEXT ONLY for now)
  // ==========================================
  void _updateFeedback() {
    // Cooldown so it doesn't change 30 times per second
    final now = DateTime.now();
    if (now.difference(_lastFeedbackTime) < _feedbackCooldown) return;
    _lastFeedbackTime = now;

    String msg = "";
    Color color = Colors.white;

    // Safety check
    if (_lastPose == null) {
      msg = "No pose detected...";
      color = Colors.orangeAccent;
    } else {
      // ==========================
      // BICEP CURL FEEDBACK
      // ==========================
      if (_selectedExercise == ExerciseType.bicepCurl) {
        final l = _bicepCounter.leftAngle;
        final r = _bicepCounter.rightAngle;

        // Basic form feedback using angles
        if (l == 0 && r == 0) {
          msg = "Bring arms into view";
          color = Colors.orangeAccent;
        } else if (l < 70 || r < 70) {
          msg = "Good! Curl up fully 💪";
          color = Colors.greenAccent;
        } else if (l > 150 && r > 150) {
          msg = "Now curl up";
          color = Colors.white;
        } else {
          msg = "Control the movement";
          color = Colors.white70;
        }
      }

      // ==========================
      // SIDE RAISE FEEDBACK
      // ==========================
      else if (_selectedExercise == ExerciseType.sideRaise) {
        final l = _sideRaiseLogic.leftAngle;
        final r = _sideRaiseLogic.rightAngle;

        if (l == 0 && r == 0) {
          msg = "Stand in frame with arms visible";
          color = Colors.orangeAccent;
        } else if (l > 75 || r > 75) {
          msg = "Great! Hold at shoulder height 🔥";
          color = Colors.greenAccent;
        } else if (l < 30 && r < 30) {
          msg = "Raise your arms sideways";
          color = Colors.white;
        } else {
          msg = "Lift higher (towards 90°)";
          color = Colors.white70;
        }
      }
    }

    // Only update UI if message changed (reduces rebuild spam)
    if (msg != _feedbackText) {
      setState(() {
        _feedbackText = msg;
        _feedbackColor = color;
      });
    }
  }

  // ==========================================
  // UI HELPERS
  // ==========================================
  String _exerciseTitle() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return "Bicep Curl";
      case ExerciseType.sideRaise:
        return "Side Raise";
      case ExerciseType.squats:
        return "Squats";
    }
  }

  int _leftReps() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.leftReps;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.leftReps;
      case ExerciseType.squats:
        return _squatLogic.reps;
    }
  }

  int _rightReps() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.rightReps;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.rightReps;
      case ExerciseType.squats:
        return _squatLogic.reps;
    }
  }

  double _computeLiveAccuracy(Pose pose) {
    // Simple angle-based scoring (0..100)
    // For mobile we use LEFT + RIGHT and average them when available.
    if (_selectedExercise == ExerciseType.bicepCurl) {
      final left = _bicepCounter.leftAngle;
      final right = _bicepCounter.rightAngle;

      double scoreFor(double angle) {
        final target = angle < 100 ? 45.0 : 165.0;
        final diff = (angle - target).abs();
        return (100 - diff * 1.2).clamp(0, 100);
      }

      final scores = <double>[];
      if (left > 0) scores.add(scoreFor(left));
      if (right > 0) scores.add(scoreFor(right));
      if (scores.isEmpty) return 0;
      return scores.reduce((a, b) => a + b) / scores.length;
    }

    if (_selectedExercise == ExerciseType.sideRaise) {
      final left = _sideRaiseLogic.leftAngle;
      final right = _sideRaiseLogic.rightAngle;

      double scoreFor(double angle) {
        final target = angle > 45 ? 90.0 : 15.0;
        final diff = (angle - target).abs();
        return (100 - diff * 1.0).clamp(0, 100);
      }

      final scores = <double>[];
      if (left > 0) scores.add(scoreFor(left));
      if (right > 0) scores.add(scoreFor(right));
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
      final diff = (kneeAngle - target).abs();
      return (100 - diff * 0.9).clamp(0, 100);
    }

    return 0;
  }

  double _angle3(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
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

  void _updateAccuracy(Pose pose) {
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

  double _leftAngle() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.leftAngle;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.leftAngle;
      case ExerciseType.squats:
        return 0;
    }
  }

  double _rightAngle() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.rightAngle;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.rightAngle;
      case ExerciseType.squats:
        return 0;
    }
  }

  String _leftStage() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.leftStage;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.leftStage;
      case ExerciseType.squats:
        return _squatLogic.reps > 0 ? "Counting" : "Ready";
    }
  }

  String _rightStage() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.rightStage;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.rightStage;
      case ExerciseType.squats:
        return _squatLogic.reps > 0 ? "Counting" : "Ready";
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

                  // Skeleton overlay
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

                  // Overlay UI
                  if (widget.showOverlayUI)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dropdown
                            Row(
                              children: [
                                const Text(
                                  "Exercise: ",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                DropdownButton<ExerciseType>(
                                  value: _selectedExercise,
                                  dropdownColor: Colors.black87,
                                  style: const TextStyle(color: Colors.white),
                                  underline: Container(
                                    height: 1,
                                    color: Colors.white24,
                                  ),
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
                                  onChanged: (val) {
                                    if (val == null) return;
                                    setState(() {
                                      _selectedExercise = val;
                                    });
                                    widget.onExerciseChanged?.call(val);
                                  },
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: "Reset reps",
                                  onPressed: _resetExercise,
                                  icon: const Icon(
                                    Icons.restart_alt,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Feedback Card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
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
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              "Left Reps: ${_leftReps()}   |   Right Reps: ${_rightReps()}\nLive Acc: ${_liveAccuracy.toStringAsFixed(0)}%   |   Avg: ${_sessionAccuracyAvg.toStringAsFixed(0)}%",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),

                            Text(
                              "Left Angle: ${_leftAngle().toStringAsFixed(1)}°  |  Right Angle: ${_rightAngle().toStringAsFixed(1)}°",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),

                            Text(
                              "Left: ${_leftStage()}  |  Right: ${_rightStage()}",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              _status,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
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
