import 'package:flutter/material.dart';
import 'pose_view.dart';
import 'camera_pose_view.dart';

class _MobilePoseViewBuilder implements PoseViewBuilder {
  @override
  Widget build() => const CameraPoseView();
}

PoseViewBuilder createPoseView() => _MobilePoseViewBuilder();