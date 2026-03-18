import 'package:flutter/material.dart';
import 'pose_view.dart';
import 'web_pose_view.dart';

class _WebPoseViewBuilder implements PoseViewBuilder {
  @override
  Widget build() => const WebPoseView();
}

PoseViewBuilder createPoseView() => _WebPoseViewBuilder();