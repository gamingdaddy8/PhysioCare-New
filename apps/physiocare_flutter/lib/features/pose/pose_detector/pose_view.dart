import 'package:flutter/material.dart';
import 'exercise_type.dart';
import 'pose_view_stub.dart'
    if (dart.library.html) 'pose_view_web.dart'
    if (dart.library.io) 'pose_view_mobile.dart';

abstract class PoseViewBuilder {
  Widget build({ExerciseType initialExercise = ExerciseType.bicepCurl});
}

class PoseView extends StatelessWidget {
  final ExerciseType initialExercise;
  const PoseView({super.key, this.initialExercise = ExerciseType.bicepCurl});

  @override
  Widget build(BuildContext context) {
    return createPoseView().build(initialExercise: initialExercise);
  }
}