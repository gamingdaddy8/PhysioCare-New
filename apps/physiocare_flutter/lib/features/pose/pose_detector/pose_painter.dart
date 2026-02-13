import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final bool isFrontCamera;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    /// ✅ Map MLKit image coordinates to preview coordinates
    Offset _mapPoint(double x, double y) {
      // scale factors
      final scaleX = size.width / imageSize.width;
      final scaleY = size.height / imageSize.height;

      double mappedX = x * scaleX;
      double mappedY = y * scaleY;

      // ✅ Fix front camera mirror issue
      if (isFrontCamera) {
        mappedX = size.width - mappedX;
      }

      return Offset(mappedX, mappedY);
    }

    // ✅ Draw all landmarks
    for (final landmark in pose.landmarks.values) {
      final p = _mapPoint(landmark.x, landmark.y);
      canvas.drawCircle(p, 5, dotPaint);
    }

    // ✅ Draw line helper
    void drawLine(PoseLandmarkType a, PoseLandmarkType b) {
      final p1 = pose.landmarks[a];
      final p2 = pose.landmarks[b];
      if (p1 == null || p2 == null) return;

      canvas.drawLine(
        _mapPoint(p1.x, p1.y),
        _mapPoint(p2.x, p2.y),
        linePaint,
      );
    }

    // ✅ Skeleton connections
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);

    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);

    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);

    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}
