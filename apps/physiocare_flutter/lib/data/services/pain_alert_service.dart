import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing in-session pain alerts.
///
/// Handles submission with retry logic, re-trigger throttling,
/// Supabase Realtime subscriptions, and alert lifecycle management.
class PainAlertService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Singleton ──────────────────────────────────────────────────
  static final PainAlertService _instance = PainAlertService._();
  factory PainAlertService() => _instance;
  PainAlertService._();

  // ── Local retry queue ──────────────────────────────────────────
  Timer? _retryTimer;
  Map<String, dynamic>? _pendingAlert;
  int _retryCount = 0;
  static const int _maxRetries = 30; // 30 × 10s = 5 minutes

  // ── Submit a pain alert ────────────────────────────────────────

  /// Submit a pain alert from the exercise session.
  ///
  /// Returns the alert ID on success, or null if queued for retry.
  /// Handles re-trigger logic: if an alert was sent within 3 minutes,
  /// updates the existing record instead of creating a new one.
  Future<String?> submitPainAlert({
    required String patientId,
    required String therapistId,
    required String exerciseTitle,
    required int painLevel,
    required String patientName,
    String? message,
    int sessionDurationSeconds = 0,
  }) async {
    final now = DateTime.now().toUtc();

    try {
      // Check for re-trigger: existing active alert within 3 minutes
      final recentAlerts = await _supabase
          .from('pain_alerts')
          .select('id, created_at')
          .eq('patient_id', patientId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1);

      if (recentAlerts is List && recentAlerts.isNotEmpty) {
        final lastAlert = recentAlerts.first;
        final lastCreated = DateTime.tryParse(
            lastAlert['created_at']?.toString() ?? '');

        if (lastCreated != null &&
            now.difference(lastCreated).inMinutes < 3) {
          // Re-trigger: update existing alert
          final alertId = lastAlert['id'].toString();
          await _supabase.from('pain_alerts').update({
            'pain_level': painLevel,
            'message': message,
            're_triggered': true,
            'session_duration_at_alert': sessionDurationSeconds,
          }).eq('id', alertId);

          debugPrint('Pain alert re-triggered: $alertId');
          return alertId;
        }
      }

      // New alert
      final payload = {
        'patient_id': patientId,
        'therapist_id': therapistId,
        'exercise_title': exerciseTitle,
        'pain_level': painLevel,
        'message': message,
        'session_duration_at_alert': sessionDurationSeconds,
        'status': 'active',
        're_triggered': false,
        'patient_name': patientName,
        'created_at': now.toIso8601String(),
      };

      final result = await _supabase
          .from('pain_alerts')
          .insert(payload)
          .select('id')
          .single();

      final alertId = result['id']?.toString();

      // Also create an in-app notification for the therapist
      await _createTherapistNotification(
        therapistId: therapistId,
        patientName: patientName,
        painLevel: painLevel,
        exerciseTitle: exerciseTitle,
        message: message,
      );

      _cancelRetry();
      debugPrint('Pain alert submitted: $alertId');
      return alertId;
    } catch (e) {
      debugPrint('Pain alert submission failed: $e — queuing for retry');
      _queueForRetry(
        patientId: patientId,
        therapistId: therapistId,
        exerciseTitle: exerciseTitle,
        painLevel: painLevel,
        patientName: patientName,
        message: message,
        sessionDurationSeconds: sessionDurationSeconds,
        originalTimestamp: now,
      );
      return null;
    }
  }

  /// Create an in-app notification for the therapist using the
  /// existing notifications table.
  Future<void> _createTherapistNotification({
    required String therapistId,
    required String patientName,
    required int painLevel,
    required String exerciseTitle,
    String? message,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': therapistId,
        'title': '🚨 Pain Alert — $patientName',
        'body':
            'Pain level $painLevel/10 during $exerciseTitle. '
            '${message != null && message.isNotEmpty ? 'Message: "$message"' : 'No message provided.'}',
        'type': 'pain_alert',
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to create therapist notification: $e');
    }
  }

  // ── Retry logic ────────────────────────────────────────────────

  void _queueForRetry({
    required String patientId,
    required String therapistId,
    required String exerciseTitle,
    required int painLevel,
    required String patientName,
    String? message,
    int sessionDurationSeconds = 0,
    required DateTime originalTimestamp,
  }) {
    _pendingAlert = {
      'patient_id': patientId,
      'therapist_id': therapistId,
      'exercise_title': exerciseTitle,
      'pain_level': painLevel,
      'patient_name': patientName,
      'message': message,
      'session_duration_at_alert': sessionDurationSeconds,
      'status': 'active',
      're_triggered': false,
      'created_at': originalTimestamp.toIso8601String(),
    };
    _retryCount = 0;
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _retrySubmit();
    });
  }

  Future<void> _retrySubmit() async {
    if (_pendingAlert == null) {
      _cancelRetry();
      return;
    }

    _retryCount++;
    if (_retryCount > _maxRetries) {
      debugPrint('Pain alert retry exhausted after 5 minutes');
      _cancelRetry();
      return;
    }

    try {
      await _supabase
          .from('pain_alerts')
          .insert(_pendingAlert!)
          .select('id')
          .single();

      // Also create notification on successful retry
      await _createTherapistNotification(
        therapistId: _pendingAlert!['therapist_id'],
        patientName: _pendingAlert!['patient_name'] ?? 'Patient',
        painLevel: _pendingAlert!['pain_level'] ?? 7,
        exerciseTitle: _pendingAlert!['exercise_title'] ?? 'Exercise',
        message: _pendingAlert!['message'],
      );

      debugPrint('Pain alert retry succeeded on attempt $_retryCount');
      _pendingAlert = null;
      _cancelRetry();
    } catch (e) {
      debugPrint('Pain alert retry #$_retryCount failed: $e');
    }
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryCount = 0;
  }

  /// Whether there is a pending alert being retried.
  bool get hasPendingAlert => _pendingAlert != null;

  // ── Fetch alerts ───────────────────────────────────────────────

  /// Fetch active (unreviewed) pain alerts for a therapist.
  Future<List<Map<String, dynamic>>> fetchActiveAlerts(
      String therapistId) async {
    final rows = await _supabase
        .from('pain_alerts')
        .select()
        .eq('therapist_id', therapistId)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Fetch all pain alerts for a specific patient (for therapist view).
  Future<List<Map<String, dynamic>>> fetchPatientAlerts(
      String patientId) async {
    final rows = await _supabase
        .from('pain_alerts')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .limit(20);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Fetch alerts from the last 30 days for a patient (for context).
  Future<List<Map<String, dynamic>>> fetchRecentAlerts({
    required String patientId,
    int days = 30,
  }) async {
    final since =
        DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String();

    final rows = await _supabase
        .from('pain_alerts')
        .select()
        .eq('patient_id', patientId)
        .gte('created_at', since)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Fetch reviewed but not yet followed-up alerts for the patient
  /// (for false-alarm prompt on patient home screen).
  Future<List<Map<String, dynamic>>> fetchReviewedAlerts(
      String patientId) async {
    final rows = await _supabase
        .from('pain_alerts')
        .select()
        .eq('patient_id', patientId)
        .eq('status', 'reviewed')
        .order('created_at', ascending: false)
        .limit(5);

    return List<Map<String, dynamic>>.from(rows);
  }

  // ── Alert actions ──────────────────────────────────────────────

  /// Mark an alert as reviewed (therapist action).
  Future<void> markAlertReviewed(String alertId) async {
    await _supabase.from('pain_alerts').update({
      'status': 'reviewed',
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', alertId);
  }

  /// Mark an alert as false alarm (patient follow-up action).
  Future<void> markFalseAlarm(String alertId) async {
    await _supabase.from('pain_alerts').update({
      'status': 'false_alarm',
    }).eq('id', alertId);
  }

  // ── Realtime subscription ──────────────────────────────────────

  /// Subscribe to real-time pain alerts for a therapist.
  /// Returns a [RealtimeChannel] that the caller should unsubscribe
  /// from when done (e.g., in dispose).
  RealtimeChannel subscribeToAlerts({
    required String therapistId,
    required void Function(Map<String, dynamic> alert) onNewAlert,
    required void Function(Map<String, dynamic> alert) onAlertUpdated,
  }) {
    final channel = _supabase.channel('pain_alerts_$therapistId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'pain_alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'therapist_id',
            value: therapistId,
          ),
          callback: (payload) {
            debugPrint('Realtime pain alert INSERT: ${payload.newRecord}');
            onNewAlert(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pain_alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'therapist_id',
            value: therapistId,
          ),
          callback: (payload) {
            debugPrint('Realtime pain alert UPDATE: ${payload.newRecord}');
            onAlertUpdated(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .subscribe();

    return channel;
  }
}
