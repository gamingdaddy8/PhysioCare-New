import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report_model.dart';
import '../models/report_period.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<ReportModel> buildReport({
    required String patientId,
    required ReportPeriod period,
  }) async {
    // ── 1. Patient profile ────────────────────────────────────
    final patientProfile = await _supabase
        .from('profiles')
        .select('full_name, condition, assigned_therapist_id')
        .eq('id', patientId)
        .maybeSingle();

    final patientName = patientProfile?['full_name']?.toString() ?? 'Patient';
    final condition = patientProfile?['condition']?.toString() ?? 'Rehab';
    final therapistId = patientProfile?['assigned_therapist_id']?.toString();

    // ── 2. Therapist details ──────────────────────────────────
    String therapistName = 'Unassigned';
    String therapistSpecialization = '';
    String therapistClinicAddress = '';
    String therapistPhone = '';
    int therapistExperienceYears = 0;

    if (therapistId != null) {
      final t = await _supabase
          .from('profiles')
          .select(
            'full_name, specialization, clinic_address, phone, experience_years',
          )
          .eq('id', therapistId)
          .maybeSingle();
      if (t != null) {
        therapistName = t['full_name']?.toString() ?? 'Unassigned';
        therapistSpecialization = t['specialization']?.toString() ?? '';
        therapistClinicAddress = t['clinic_address']?.toString() ?? '';
        therapistPhone = t['phone']?.toString() ?? '';
        therapistExperienceYears =
            (t['experience_years'] as num?)?.toInt() ?? 0;
      }
    }

    // ── 3. Build date range ───────────────────────────────────
    final dateRange = _dateRange(period);
    final fromDate = dateRange.$1;
    final toDate = dateRange.$2;

    // ── 4. Fetch session_reports ──────────────────────────────
    // Build query step by step to avoid chaining on the wrong builder type
    List<dynamic> rawSessions;

    if (period == ReportPeriod.session) {
      // Just the single most recent session
      rawSessions = await _supabase
          .from('session_reports')
          .select(
            'id, exercise_title, reps_done, duration_seconds, accuracy, created_at',
          )
          .eq('patient_id', patientId)
          .order('created_at', ascending: false)
          .limit(1);
    } else if (fromDate != null && toDate != null) {
      rawSessions = await _supabase
          .from('session_reports')
          .select(
            'id, exercise_title, reps_done, duration_seconds, accuracy, created_at',
          )
          .eq('patient_id', patientId)
          .gte('created_at', fromDate)
          .lte('created_at', toDate)
          .order('created_at', ascending: false);
    } else {
      // ReportPeriod.all — no date filter
      rawSessions = await _supabase
          .from('session_reports')
          .select(
            'id, exercise_title, reps_done, duration_seconds, accuracy, created_at',
          )
          .eq('patient_id', patientId)
          .order('created_at', ascending: false);
    }

    final sessions = rawSessions
        .map((m) => SessionRow.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();

    // ── 5. Therapist feedback ─────────────────────────────────
    final rawFeedback = await _supabase
        .from('therapist_feedback')
        .select('message, created_at')
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .limit(10);

    final feedback = (rawFeedback as List)
        .map((m) => FeedbackRow.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();

    // ── 6. Assemble model ─────────────────────────────────────
    return ReportModel.fromSessions(
      patientId: patientId,
      patientName: patientName,
      condition: condition,
      therapistName: therapistName,
      therapistSpecialization: therapistSpecialization,
      therapistClinicAddress: therapistClinicAddress,
      therapistPhone: therapistPhone,
      therapistExperienceYears: therapistExperienceYears,
      period: period,
      sessions: sessions,
      therapistFeedback: feedback,
    );
  }

  /// Save summary stats to the `reports` table. Returns the new row id.
  Future<String?> saveReport(ReportModel report) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return null;

      final row = await _supabase
          .from('reports')
          .insert({
            'patient_id': report.patientId,
            'therapist_id': currentUser.id,
            'period': report.period.dbValue,
            'period_label': report.period.label,
            'total_sessions': report.totalSessions,
            'total_reps': report.totalReps,
            'total_minutes': report.totalMinutes,
            'avg_accuracy': report.avgAccuracy,
            'avg_reps': report.avgReps,
            'best_reps': report.bestReps,
            'ai_summary': report.aiSummary,
            'exercise_breakdown': report.exerciseBreakdown,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      return row['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  (String?, String?) _dateRange(ReportPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case ReportPeriod.session:
        return (null, null);
      case ReportPeriod.day:
        return ('${_fmt(today)}T00:00:00', '${_fmt(today)}T23:59:59');
      case ReportPeriod.week:
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return ('${_fmt(weekStart)}T00:00:00', '${_fmt(today)}T23:59:59');
      case ReportPeriod.all:
        return (null, null);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
