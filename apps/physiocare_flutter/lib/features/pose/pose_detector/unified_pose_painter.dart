import 'dart:ui';
import 'package:flutter/material.dart';
import 'unified_pose.dart';

class UnifiedPosePainter extends CustomPainter {
  final UnifiedPose pose;
  final Size sourceSize; // size of the original video/frame
  final bool isNormalized; // true for MediaPipe (0..1)

  UnifiedPosePainter({
    required this.pose,
    required this.sourceSize,
    required this.isNormalized,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    Offset? p(int idx) {
      if (idx < 0 || idx >= pose.landmarks.length) return null;
      final lm = pose.landmarks[idx];
      if (lm.visibility < 0.3) return null;

      final dx = isNormalized ? lm.x * size.width : (lm.x / sourceSize.width) * size.width;
      final dy = isNormalized ? lm.y * size.height : (lm.y / sourceSize.height) * size.height;

      return Offset(dx, dy);
    }

    void drawPoint(int idx) {
      final pt = p(idx);
      if (pt == null) return;
      canvas.drawCircle(pt, 4, paint);
    }

    void drawLine(int a, int b) {
      final pa = p(a);
      final pb = p(b);
      if (pa == null || pb == null) return;
      canvas.drawLine(pa, pb, linePaint);
    }

    // MediaPipe Pose landmark indices
    // 0 nose, 11 leftShoulder, 12 rightShoulder, 13 leftElbow, 14 rightElbow
    // 15 leftWrist, 16 rightWrist, 23 leftHip, 24 rightHip, 25 leftKnee, 26 rightKnee
    // 27 leftAnkle, 28 rightAnkle

    // Torso
    drawLine(11, 12);
    drawLine(11, 23);
    drawLine(12, 24);
    drawLine(23, 24);

    // Left arm
    drawLine(11, 13);
    drawLine(13, 15);

    // Right arm
    drawLine(12, 14);
    drawLine(14, 16);

    // Left leg
    drawLine(23, 25);
    drawLine(25, 27);

    // Right leg
    drawLine(24, 26);
    drawLine(26, 28);

    // Draw key points
    for (final idx in [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]) {
      drawPoint(idx);
    }
  }

  @override
  bool shouldRepaint(covariant UnifiedPosePainter oldDelegate) {
    return oldDelegate.pose != pose;
  }
}
