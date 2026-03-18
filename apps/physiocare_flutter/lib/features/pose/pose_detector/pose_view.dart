import 'package:flutter/material.dart';
import 'pose_view_stub.dart'
    if (dart.library.html) 'pose_view_web.dart'
    if (dart.library.io) 'pose_view_mobile.dart';

abstract class PoseViewBuilder {
  Widget build();
}

class PoseView extends StatelessWidget {
  const PoseView({super.key});

  @override
  Widget build(BuildContext context) {
    return createPoseView().build();
  }
}