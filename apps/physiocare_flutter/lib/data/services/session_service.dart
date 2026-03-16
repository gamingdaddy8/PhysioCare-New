import 'package:supabase_flutter/supabase_flutter.dart';

class SessionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Save a completed session report
  Future<void> saveSessionReport({
    required String patientId,
    required String exerciseId,
    required String exerciseTitle,
    required int repsDone,
    required int durationSeconds,
    String? therapistId,
    double accuracy = 0,
    String? notes,
  }) async {
    await _supabase.from('session_reports').insert({
      'patient_id':       patientId,
      'therapist_id':     therapistId,
      'exercise_id':      exerciseId,
      'exercise_title':   exerciseTitle,
      'reps_done':        repsDone,
      'duration_seconds': durationSeconds,
      'accuracy':         accuracy,
      'notes':            notes,
      'created_at':       DateTime.now().toIso8601String(),
    });
  }

  // Fetch session reports for a patient
  Future<List<Map<String, dynamic>>> fetchSessionReports({
    required String patientId,
    int limit = 50,
  }) async {
    final rows = await _supabase
        .from('session_reports')
        .select('''
          id,
          reps_done,
          duration_seconds,
          accuracy,
          notes,
          exercise_title,
          created_at
        ''')
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(rows);
  }

  // Fetch sessions for a specific patient (for therapist view)
  Future<List<Map<String, dynamic>>> fetchPatientSessions({
    required String patientId,
    int limit = 10,
  }) async {
    return fetchSessionReports(patientId: patientId, limit: limit);
  }

  // Count today's sessions for a patient
  Future<int> countTodaySessions({required String patientId}) async {
    final today    = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final rows = await _supabase
        .from('session_reports')
        .select('id')
        .eq('patient_id', patientId)
        .gte('created_at', '${todayStr}T00:00:00')
        .lte('created_at', '${todayStr}T23:59:59');

    return (rows as List).length;
  }
}