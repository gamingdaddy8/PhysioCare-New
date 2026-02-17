import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'camera_pose_view.dart';
import 'web_pose_view.dart';

class CameraPoseScreen extends StatelessWidget {
  const CameraPoseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Web -> MediaPipe
    if (kIsWeb) {
      return const WebPoseView();
    }

    // ✅ Mobile -> ML Kit + Camera
    return const CameraPoseView();
  }
}