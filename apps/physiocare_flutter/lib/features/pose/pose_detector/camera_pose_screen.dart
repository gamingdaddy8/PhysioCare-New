import 'package:flutter/material.dart';
import 'pose_view.dart';

import 'exercise_type.dart';

class CameraPoseScreen extends StatelessWidget {
  final ExerciseType initialExercise;
  const CameraPoseScreen({super.key, this.initialExercise = ExerciseType.bicepCurl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PoseView(initialExercise: initialExercise),
      ),
    );
  }
}