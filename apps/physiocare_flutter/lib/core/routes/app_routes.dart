import 'package:flutter/material.dart';

import '../../features/auth/screens/landing_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';

import '../../features/patient/home/patient_portal_home_screen.dart';
import '../../features/patient/exercises/my_exercises_screen.dart';
import '../../features/patient/reports/session_reports_screen.dart';
import '../../features/reports/screens/patient_report_screen.dart';
import '../../features/reports/screens/therapist_report_screen.dart';

import '../../features/pose/pose_detector/camera_pose_screen.dart';
import '../../features/pose/session/exercise_session_screen.dart';

import '../../features/therapist/home/therapist_home_screen.dart';
import '../../features/appointments/screens/book_appointment_screen.dart';
import '../../features/appointments/screens/my_appointments_screen.dart';
import '../../features/appointments/screens/therapist_bookings_screen.dart';
import '../../features/appointments/screens/therapist_availability_screen.dart';
import '../../features/appointments/screens/notifications_screen.dart';

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

  // Reports
  static const patientReport = "/patient-report";
  static const therapistReport = "/therapist-report";

  // Appointments
  static const bookAppointment          = '/book-appointment';
  static const myAppointments           = '/my-appointments';
  static const therapistBookings        = '/therapist-bookings';
  static const therapistAvailability    = '/therapist-availability';
  static const notifications            = '/notifications';

  static Map<String, WidgetBuilder> routes = {
    // First screen
    splash: (context) => const LandingScreen(),

    // Auth
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),

    // Patient Portal
    patientHome: (context) => const PatientPortalHomeScreen(),
    patientExercises: (context) => const MyExercisesScreen(),
    patientReports: (context) => const SessionReportsScreen(),

    // Schedule placeholder (for now)
    patientSchedule: (context) => const Scaffold(
          body: Center(child: Text("Schedule page (TODO)")),
        ),

    // Therapist Portal
    therapistHome: (context) => const TherapistHomeScreen(),

    // Pose screen (this internally decides Web vs Mobile later)
    poseTest: (context) => const CameraPoseScreen(),

    // Exercise session UI
    exerciseSession: (context) => const ExerciseSessionScreen(),

    // Reports
    patientReport: (context) => const PatientReportScreen(),
    therapistReport: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
      return TherapistReportScreen(
        patientId: args['patientId'] ?? '',
        patientName: args['patientName'] ?? 'Patient',
      );
    },

    // Appointments
    bookAppointment:       (context) => const BookAppointmentScreen(),
    myAppointments:        (context) => const MyAppointmentsScreen(),
    therapistBookings:     (context) => const TherapistBookingsScreen(),
    therapistAvailability: (context) => const TherapistAvailabilityScreen(),
    notifications:         (context) => const NotificationsScreen(),
  };
}