import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'mlkit_pose_service.dart';
import 'dart:typed_data';
import 'dart:ui';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';


class CameraPoseScreen extends StatefulWidget {
  const CameraPoseScreen({super.key});

  @override
  State<CameraPoseScreen> createState() => _CameraPoseScreenState();
}

class _CameraPoseScreenState extends State<CameraPoseScreen> {
  CameraController? _cameraController;
  late final MLKitPoseService _poseService;

  bool _isBusy = false;
  String _status = "Initializing...";

  @override
  void initState() {
    super.initState();
    _poseService = MLKitPoseService();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      // Prefer front camera
      final selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      await _cameraController!.startImageStream((CameraImage image) async {
        if (_isBusy) return;
        _isBusy = true;

        try {
          final inputImage = _convertCameraImageToInputImage(image);
          final poses = await _poseService.processImage(inputImage);

          if (poses.isNotEmpty) {
            final landmarksCount = poses.first.landmarks.length;
            setState(() {
              _status = "Pose detected ✅ Landmarks: $landmarksCount";
            });

            // Print landmark example
            final nose = poses.first.landmarks[PoseLandmarkType.nose];
            if (nose != null) {
              // ignore: avoid_print
              print("Nose: x=${nose.x}, y=${nose.y}");
            }
          } else {
            setState(() {
              _status = "No pose detected...";
            });
          }
        } catch (e) {
          setState(() {
            _status = "Error: $e";
          });
        }

        _isBusy = false;
      });

      setState(() {
        _status = "Camera started ✅";
      });
    } catch (e) {
      setState(() {
        _status = "Camera init failed: $e";
      });
    }
  }

  // NOTE: For now, this is a placeholder.
  // We will implement a correct conversion next step.
  InputImage _convertCameraImageToInputImage(CameraImage image) {
    throw UnimplementedError(
      "CameraImage -> InputImage conversion is next step",
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return Scaffold(
      appBar: AppBar(title: const Text("Pose Detection Test")),
      body: Column(
        children: [
          if (controller != null && controller.value.isInitialized)
            Expanded(child: CameraPreview(controller))
          else
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _status,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
