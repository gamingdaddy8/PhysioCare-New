import 'package:flutter/material.dart';
import 'pose_view.dart';
import 'web_pose_view.dart';

import 'exercise_type.dart';

class _WebPoseViewBuilder implements PoseViewBuilder {
  @override
  Widget build({ExerciseType initialExercise = ExerciseType.bicepCurl}) => 
      WebPoseView(initialExercise: initialExercise);
}

PoseViewBuilder createPoseView() => _WebPoseViewBuilder();