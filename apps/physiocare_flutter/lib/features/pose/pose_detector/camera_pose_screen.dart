import 'package:flutter/material.dart';
import 'pose_view.dart';

class CameraPoseScreen extends StatelessWidget {
  const CameraPoseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: PoseView(),
      ),
    );
  }
}