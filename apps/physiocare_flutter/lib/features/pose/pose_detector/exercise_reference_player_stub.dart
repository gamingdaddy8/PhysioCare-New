import 'package:flutter/material.dart';
import 'exercise_type.dart';

/// Stub class for native platforms. The real player uses web APIs to iframe 
/// YouTube videos, which fails compilation on Android/iOS.
class ExerciseReferencePlayer extends StatelessWidget {
  final ExerciseType exercise;

  const ExerciseReferencePlayer({
    super.key,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.videocam_off_outlined,
              size: 40, color: Color(0xFF64748B)),
          SizedBox(height: 12),
          Text('Reference video available on web only',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('Please use the live camera detection to practice.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        ],
      ),
    );
  }
}
