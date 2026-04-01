import 'package:flutter/material.dart';
import 'exercise_type.dart';

/// Stub class for native platforms. The real WebPoseView requires dart:js_interop, 
/// which fails to compile on Android/iOS in some SDK versions.
class WebPoseView extends StatefulWidget {
  const WebPoseView({
    super.key,
    this.initialExercise = ExerciseType.bicepCurl,
    this.onRepCompleted,
    this.onAccuracyUpdated,
    this.targetReps = 0,
  });

  final ExerciseType initialExercise;
  final ValueChanged<int>? onRepCompleted;
  final ValueChanged<double>? onAccuracyUpdated;
  final int targetReps;

  @override
  State<WebPoseView> createState() => _WebPoseViewState();
}

class _WebPoseViewState extends State<WebPoseView> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
