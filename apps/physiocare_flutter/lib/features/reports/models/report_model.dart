import 'report_period.dart';

class SessionRow {
  final String id;
  final String exerciseTitle;
  final int repsDone;
  final int durationSeconds;
  final double accuracy;
  final DateTime createdAt;

  const SessionRow({
    required this.id,
    required this.exerciseTitle,
    required this.repsDone,
    required this.durationSeconds,
    required this.accuracy,
    required this.createdAt,
  });

  factory SessionRow.fromMap(Map<String, dynamic> m) {
    return SessionRow(
      id: m['id']?.toString() ?? '',
      exerciseTitle: m['exercise_title']?.toString() ?? 'Exercise',
      repsDone: (m['reps_done'] as num?)?.toInt() ?? 0,
      durationSeconds: (m['duration_seconds'] as num?)?.toInt() ?? 0,
      accuracy: (m['accuracy'] as num?)?.toDouble() ?? 0.0,
      createdAt:
          DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class FeedbackRow {
  final String message;
  final DateTime createdAt;

  const FeedbackRow({required this.message, required this.createdAt});

  factory FeedbackRow.fromMap(Map<String, dynamic> m) {
    return FeedbackRow(
      message: m['message']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ReportModel {
  // ── Identity ──────────────────────────────────────────────────
  final String patientId;
  final String patientName;
  final String condition;
  final String therapistName;
  final String therapistSpecialization;
  final String therapistClinicAddress;
  final String therapistPhone;
  final int therapistExperienceYears;
  final ReportPeriod period;
  final DateTime generatedAt;

  // ── Raw data ──────────────────────────────────────────────────
  final List<SessionRow> sessions;
  final List<FeedbackRow> therapistFeedback;

  // ── Computed stats ────────────────────────────────────────────
  final int totalSessions;
  final int totalReps;
  final int totalMinutes;
  final double avgReps;
  final double avgAccuracy;
  final int bestReps;
  final double bestAccuracy;
  final Map<String, int> exerciseBreakdown;

  // ── AI + notes ────────────────────────────────────────────────
  final String aiSummary;
  final String? therapistNotes;
  final String? savedReportId;

  const ReportModel({
    required this.patientId,
    required this.patientName,
    required this.condition,
    required this.therapistName,
    required this.therapistSpecialization,
    required this.therapistClinicAddress,
    required this.therapistPhone,
    required this.therapistExperienceYears,
    required this.period,
    required this.generatedAt,
    required this.sessions,
    required this.therapistFeedback,
    required this.totalSessions,
    required this.totalReps,
    required this.totalMinutes,
    required this.avgReps,
    required this.avgAccuracy,
    required this.bestReps,
    required this.bestAccuracy,
    required this.exerciseBreakdown,
    required this.aiSummary,
    this.therapistNotes,
    this.savedReportId,
  });

  factory ReportModel.fromSessions({
    required String patientId,
    required String patientName,
    required String condition,
    required String therapistName,
    required String therapistSpecialization,
    required String therapistClinicAddress,
    required String therapistPhone,
    required int therapistExperienceYears,
    required ReportPeriod period,
    required List<SessionRow> sessions,
    required List<FeedbackRow> therapistFeedback,
    String aiSummary = '',
  }) {
    final totalSessions = sessions.length;
    final totalReps = sessions.fold(0, (s, r) => s + r.repsDone);
    final totalSeconds = sessions.fold(0, (s, r) => s + r.durationSeconds);
    final totalMinutes = (totalSeconds / 60).round();

    final avgReps = totalSessions == 0 ? 0.0 : totalReps / totalSessions;

    final avgAccuracy = totalSessions == 0
        ? 0.0
        : sessions.fold(0.0, (s, r) => s + r.accuracy) / totalSessions;

    int bestReps = 0;
    double bestAccuracy = 0.0;
    if (sessions.isNotEmpty) {
      bestReps = sessions
          .map((r) => r.repsDone)
          .reduce((a, b) => a > b ? a : b);
      bestAccuracy = sessions
          .map((r) => r.accuracy)
          .reduce((a, b) => a > b ? a : b);
    }

    final breakdown = <String, int>{};
    for (final s in sessions) {
      breakdown[s.exerciseTitle] =
          (breakdown[s.exerciseTitle] ?? 0) + s.repsDone;
    }

    return ReportModel(
      patientId: patientId,
      patientName: patientName,
      condition: condition,
      therapistName: therapistName,
      therapistSpecialization: therapistSpecialization,
      therapistClinicAddress: therapistClinicAddress,
      therapistPhone: therapistPhone,
      therapistExperienceYears: therapistExperienceYears,
      period: period,
      generatedAt: DateTime.now(),
      sessions: sessions,
      therapistFeedback: therapistFeedback,
      totalSessions: totalSessions,
      totalReps: totalReps,
      totalMinutes: totalMinutes,
      avgReps: avgReps,
      avgAccuracy: avgAccuracy,
      bestReps: bestReps,
      bestAccuracy: bestAccuracy,
      exerciseBreakdown: breakdown,
      aiSummary: aiSummary,
    );
  }

  /// "Improving" / "Stable" / "Declining" / "Not enough data"
  String get progressTrend {
    if (sessions.length < 6) return 'Not enough data';
    final first3avg = sessions.take(3).fold(0, (s, r) => s + r.repsDone) / 3;
    final last3avg =
        sessions.reversed.take(3).fold(0, (s, r) => s + r.repsDone) / 3;
    if (last3avg > first3avg * 1.05) return 'Improving';
    if (last3avg < first3avg * 0.95) return 'Declining';
    return 'Stable';
  }

  ReportModel copyWith({
    String? aiSummary,
    String? therapistNotes,
    String? savedReportId,
  }) {
    return ReportModel(
      patientId: patientId,
      patientName: patientName,
      condition: condition,
      therapistName: therapistName,
      therapistSpecialization: therapistSpecialization,
      therapistClinicAddress: therapistClinicAddress,
      therapistPhone: therapistPhone,
      therapistExperienceYears: therapistExperienceYears,
      period: period,
      generatedAt: generatedAt,
      sessions: sessions,
      therapistFeedback: therapistFeedback,
      totalSessions: totalSessions,
      totalReps: totalReps,
      totalMinutes: totalMinutes,
      avgReps: avgReps,
      avgAccuracy: avgAccuracy,
      bestReps: bestReps,
      bestAccuracy: bestAccuracy,
      exerciseBreakdown: exerciseBreakdown,
      aiSummary: aiSummary ?? this.aiSummary,
      therapistNotes: therapistNotes ?? this.therapistNotes,
      savedReportId: savedReportId ?? this.savedReportId,
    );
  }
}
