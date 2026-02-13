import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../rep_counter/bicep_curl_counter.dart';
import '../rep_counter/side_raise_logic.dart';

import 'mlkit_pose_service.dart';
import 'pose_painter.dart';

enum ExerciseType {
  bicepCurl,
  sideRaise,
}

class CameraPoseScreen extends StatefulWidget {
  const CameraPoseScreen({super.key});

  @override
  State<CameraPoseScreen> createState() => _CameraPoseScreenState();
}

class _CameraPoseScreenState extends State<CameraPoseScreen> {
  CameraController? _cameraController;
  late final MLKitPoseService _poseService;

  bool _isBusy = false;
  bool _isStreaming = false;

  String _status = "Initializing...";
  Pose? _lastPose;

  // ==========================
  // Exercise Selection
  // ==========================
  ExerciseType _selectedExercise = ExerciseType.bicepCurl;

  // ==========================
  // Exercise Logic Objects
  // ==========================
  final BicepCurlCounter _bicepCounter = BicepCurlCounter();
  final SideRaiseLogic _sideRaiseLogic = SideRaiseLogic();

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
        ResolutionPreset.veryHigh,
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
            _lastPose = poses.first;

            // ==========================
            // Update Selected Exercise Logic
            // ==========================
            if (_selectedExercise == ExerciseType.bicepCurl) {
              _bicepCounter.update(_lastPose!);
            } else if (_selectedExercise == ExerciseType.sideRaise) {
              _sideRaiseLogic.update(_lastPose!);
            }

            setState(() {
              _status = "Pose detected ✅";
            });
          } else {
            setState(() {
              _status = "No pose detected...";
              _lastPose = null;
            });
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
      _bicepCounter.reset();
      _sideRaiseLogic.reset();
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
  // UI HELPERS
  // ==========================================
  String _exerciseTitle() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return "Bicep Curl";
      case ExerciseType.sideRaise:
        return "Side Raise";
    }
  }

  int _leftReps() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.leftReps;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.leftReps;
    }
  }

  int _rightReps() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.rightReps;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.rightReps;
    }
  }

  double _leftAngle() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.leftAngle;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.leftAngle;
    }
  }

  double _rightAngle() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.rightAngle;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.rightAngle;
    }
  }

  String _leftStage() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.leftStage;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.leftStage;
    }
  }

  String _rightStage() {
    switch (_selectedExercise) {
      case ExerciseType.bicepCurl:
        return _bicepCounter.rightStage;
      case ExerciseType.sideRaise:
        return _sideRaiseLogic.rightStage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return Scaffold(
      appBar: AppBar(
        title: Text("Exercise Test - ${_exerciseTitle()}"),
        actions: [
          IconButton(
            onPressed: _resetExercise,
            icon: const Icon(Icons.restart_alt),
            tooltip: "Reset reps",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
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
                                    ],
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setState(() {
                                        _selectedExercise = val;
                                      });
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              Text(
                                "Left Reps: ${_leftReps()}   |   Right Reps: ${_rightReps()}",
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
        ],
      ),
    );
  }
}
