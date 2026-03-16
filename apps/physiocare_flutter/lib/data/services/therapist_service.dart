import 'package:supabase_flutter/supabase_flutter.dart';

class TherapistService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Dashboard data ───────────────────────────────────────────

  /// Fetch the therapist's own profile.
  Future<Map<String, dynamic>?> fetchTherapistProfile(
      String therapistId) async {
    return await _supabase
        .from('profiles')
        .select()
        .eq('id', therapistId)
        .maybeSingle();
  }

  /// Fetch all patients assigned to this therapist.
  Future<List<Map<String, dynamic>>> fetchPatients(
      String therapistId) async {
    final rows = await _supabase
        .from('profiles')
        .select()
        .eq('role', 'patient')
        .eq('assigned_therapist_id', therapistId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  // ── Patient detail ───────────────────────────────────────────

  /// Fetch a single patient's profile.
  Future<Map<String, dynamic>?> fetchPatientProfile(
      String patientId) async {
    return await _supabase
        .from('profiles')
        .select()
        .eq('id', patientId)
        .maybeSingle();
  }

  /// Fetch assigned exercises for a patient by this therapist.
  Future<List<Map<String, dynamic>>> fetchAssignedExercises({
    required String patientId,
    required String therapistId,
  }) async {
    final rows = await _supabase
        .from('assigned_exercises')
        .select('''
          id,
          reps,
          sets,
          sessions_per_day,
          total_days,
          start_date,
          end_date,
          status,
          created_at,
          exercises ( title )
        ''')
        .eq('patient_id', patientId)
        .eq('therapist_id', therapistId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Assign an exercise to a patient.
  Future<void> assignExercise({
    required String patientId,
    required String therapistId,
    required String exerciseId,
    required int reps,
    required int totalDays,
    required int sessionsPerDay,
    int sets = 3,
  }) async {
    final startDate = DateTime.now();
    final endDate   = startDate.add(Duration(days: totalDays - 1));

    final fmt = (DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    await _supabase.from('assigned_exercises').insert({
      'patient_id':       patientId,
      'therapist_id':     therapistId,
      'exercise_id':      exerciseId,
      'reps':             reps,
      'sets':             sets,
      'sessions_per_day': sessionsPerDay,
      'total_days':       totalDays,
      'start_date':       fmt(startDate),
      'end_date':         fmt(endDate),
      'status':           'active',
    });
  }

  // ── Session reports ──────────────────────────────────────────

  /// Fetch recent session reports for a patient.
  Future<List<Map<String, dynamic>>> fetchSessionReports({
    required String patientId,
    int limit = 10,
  }) async {
    final rows = await _supabase
        .from('session_reports')
        .select('''
          id,
          reps_done,
          duration_seconds,
          notes,
          exercise_title,
          created_at
        ''')
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(rows);
  }

  // ── Feedback ─────────────────────────────────────────────────

  /// Send a feedback message to a patient.
  Future<void> sendFeedback({
    required String therapistId,
    required String patientId,
    required String message,
  }) async {
    await _supabase.from('therapist_feedback').insert({
      'therapist_id': therapistId,
      'patient_id':   patientId,
      'message':      message,
      'created_at':   DateTime.now().toIso8601String(),
    });
  }

  /// Fetch feedback sent by this therapist to a patient.
  Future<List<Map<String, dynamic>>> fetchFeedback({
    required String therapistId,
    required String patientId,
  }) async {
    final rows = await _supabase
        .from('therapist_feedback')
        .select()
        .eq('therapist_id', therapistId)
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .limit(20);

    return List<Map<String, dynamic>>.from(rows);
  }

  // ── Pain alerts ──────────────────────────────────────────────

  /// Fetch pending pain alerts from all patients of this therapist.
  Future<List<Map<String, dynamic>>> fetchPainAlerts(
      String therapistId) async {
    final rows = await _supabase
        .from('pain_reports')
        .select('''
          id,
          pain_level,
          description,
          status,
          created_at,
          patient_id
        ''')
        .eq('therapist_id', therapistId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Mark a pain alert as reviewed.
  Future<void> markPainAlertReviewed(String reportId) async {
    await _supabase
        .from('pain_reports')
        .update({'status': 'reviewed'})
        .eq('id', reportId);
  }

  // ── Stats ────────────────────────────────────────────────────

  /// Get summary stats for the therapist dashboard.
  /// Returns: { patients, pendingAlerts, totalSessions }
  Future<Map<String, int>> fetchDashboardStats(
      String therapistId) async {
    final patients = await fetchPatients(therapistId);
    final alerts   = await fetchPainAlerts(therapistId);

    // Count all sessions across all patients
    int totalSessions = 0;
    for (final p in patients) {
      final patientId = p['id']?.toString();
      if (patientId == null) continue;
      final sessions = await _supabase
          .from('session_reports')
          .select('id')
          .eq('patient_id', patientId);
      totalSessions += (sessions as List).length;
    }

    return {
      'patients':       patients.length,
      'pendingAlerts':  alerts.length,
      'totalSessions':  totalSessions,
    };
  }
}