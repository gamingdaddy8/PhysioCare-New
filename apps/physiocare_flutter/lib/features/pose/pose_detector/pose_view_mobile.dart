import 'package:flutter/material.dart';
import 'pose_view.dart';
import 'camera_pose_view.dart';

import 'exercise_type.dart';

class _MobilePoseViewBuilder implements PoseViewBuilder {
  @override
  Widget build({ExerciseType initialExercise = ExerciseType.bicepCurl}) => 
      CameraPoseView(initialExercise: initialExercise);
}

PoseViewBuilder createPoseView() => _MobilePoseViewBuilder();