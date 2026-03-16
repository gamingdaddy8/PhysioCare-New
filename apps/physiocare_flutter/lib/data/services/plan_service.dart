import 'package:supabase_flutter/supabase_flutter.dart';

class PlanService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Submit a pain report
  Future<void> submitPainReport({
    required String patientId,
    required int painLevel,
    String? description,
    String? therapistId,
  }) async {
    await _supabase.from('pain_reports').insert({
      'patient_id':   patientId,
      'therapist_id': therapistId,
      'pain_level':   painLevel,
      'description':  description,
      'status':       'pending',
      'created_at':   DateTime.now().toIso8601String(),
    });
  }

  // Fetch pain reports for a patient
  Future<List<Map<String, dynamic>>> fetchPainReports({
    required String patientId,
  }) async {
    final rows = await _supabase
        .from('pain_reports')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  // Fetch pending pain alerts for a therapist
  Future<List<Map<String, dynamic>>> fetchPainAlerts({
    required String therapistId,
  }) async {
    final rows = await _supabase
        .from('pain_reports')
        .select('''
          id,
          pain_level,
          description,
          status,
          created_at,
          profiles!pain_reports_patient_id_fkey ( full_name )
        ''')
        .eq('therapist_id', therapistId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  // Mark pain alert as reviewed
  Future<void> markPainReviewed({required String reportId}) async {
    await _supabase
        .from('pain_reports')
        .update({'status': 'reviewed'})
        .eq('id', reportId);
  }

  // Send therapist feedback to patient
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

  // Fetch feedback for a patient
  Future<List<Map<String, dynamic>>> fetchFeedback({
    required String patientId,
    String? therapistId,
  }) async {
    var query = _supabase
        .from('therapist_feedback')
        .select()
        .eq('patient_id', patientId);

    if (therapistId != null) {
      query = query.eq('therapist_id', therapistId);
    }

    final rows = await query.order('created_at', ascending: false).limit(20);
    return List<Map<String, dynamic>>.from(rows);
  }
}