import 'package:flutter/material.dart';

import '../../features/auth/screens/landing_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';

import '../../features/patient/home/patient_portal_home_screen.dart';
import '../../features/patient/exercises/my_exercises_screen.dart';

import '../../features/pose/pose_detector/camera_pose_screen.dart';
import '../../features/pose/session/exercise_session_screen.dart';

import '../../features/therapist/home/therapist_home_screen.dart';

// Report feature — new PatientReportScreen replaces the old SessionReportsScreen
import '../../features/reports/screens/patient_report_screen.dart';

class AppRoutes {
  static const splash = "/";
  static const login = "/login";
  static const register = "/register";

  // Patient Portal
  static const patientHome = "/patient-home";
  static const patientExercises = "/patient-exercises";
  static const patientReports = "/patient-reports";
  static const patientSchedule = "/patient-schedule";

  // Therapist Portal
  static const therapistHome = "/therapist-home";

  // Pose / Exercise
  static const poseTest = "/pose-test";
  static const exerciseSession = "/exercise-session";

  // Note: TherapistReportScreen is opened via Navigator.push (not a named route)
  // because it requires patientId + patientName arguments passed at call-site.

  static Map<String, WidgetBuilder> routes = {
    // First screen
    splash: (context) => const LandingScreen(),

    // Auth
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),

    // Patient Portal
    patientHome: (context) => const PatientPortalHomeScreen(),
    patientExercises: (context) => const MyExercisesScreen(),
    patientReports: (context) => const PatientReportScreen(),

    // Schedule placeholder (for now)
    patientSchedule: (context) => const Scaffold(
          body: Center(child: Text("Schedule page (TODO)")),
        ),

    // Therapist Portal
    therapistHome: (context) => const TherapistHomeScreen(),

    // Pose screen (decides Web vs Mobile internally)
    poseTest: (context) => const CameraPoseScreen(),

    // Exercise session UI
    exerciseSession: (context) => const ExerciseSessionScreen(),
  };
}