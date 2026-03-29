import 'package:supabase_flutter/supabase_flutter.dart';

class ExerciseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch all exercises from master catalog
  Future<List<Map<String, dynamic>>> fetchAllExercises() async {
    final rows = await _supabase
        .from('exercises')
        .select('id, title, description, category, default_reps, default_sets')
        .order('title');
    return List<Map<String, dynamic>>.from(rows);
  }

  // Fetch assigned exercises for a patient (active only by default)
  Future<List<Map<String, dynamic>>> fetchAssignedExercises({
    required String patientId,
    String? status, // null = all, 'active', 'completed', 'paused'
  }) async {
    var query = _supabase
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
          exercises ( id, title, description, category )
        ''')
        .eq('patient_id', patientId);

    if (status != null) {
      query = query.eq('status', status);
    }

    final rows = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  // Assign an exercise to a patient
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

  // Update status of an assigned exercise
  Future<void> updateAssignedStatus({
    required String assignedExerciseId,
    required String status,
  }) async {
    await _supabase
        .from('assigned_exercises')
        .update({'status': status})
        .eq('id', assignedExerciseId);
  }
}