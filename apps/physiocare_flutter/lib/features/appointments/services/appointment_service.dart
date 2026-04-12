import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment_models.dart';

class AppointmentService {
  final SupabaseClient _db = Supabase.instance.client;

  // ── Availability ─────────────────────────────────────────────────────────────

  /// Fetch all availability rows for a therapist.
  Future<List<AvailabilitySlot>> fetchAvailability(String therapistId) async {
    final rows = await _db
        .from('therapist_availability')
        .select()
        .eq('therapist_id', therapistId)
        .eq('is_available', true)
        .order('day_of_week')
        .order('start_time');
    return (rows as List)
        .map((m) => AvailabilitySlot.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Upsert a single availability window (insert or update by id).
  Future<void> upsertAvailability({
    required String therapistId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    int slotDurationMinutes = 30,
    String? existingId,
  }) async {
    final payload = {
      'therapist_id':          therapistId,
      'day_of_week':           dayOfWeek,
      'start_time':            startTime,
      'end_time':              endTime,
      'slot_duration_minutes': slotDurationMinutes,
      'is_available':          true,
    };
    if (existingId != null && existingId.isNotEmpty) {
      await _db
          .from('therapist_availability')
          .update(payload)
          .eq('id', existingId);
    } else {
      await _db.from('therapist_availability').insert(payload);
    }
  }

  /// Delete an availability window.
  Future<void> deleteAvailability(String id) async {
    await _db.from('therapist_availability').delete().eq('id', id);
  }

  // ── Blocked dates ─────────────────────────────────────────────────────────────

  Future<List<BlockedDate>> fetchBlockedDates(String therapistId) async {
    final rows = await _db
        .from('therapist_blocked_dates')
        .select()
        .eq('therapist_id', therapistId)
        .gte('blocked_date', DateTime.now().toIso8601String().substring(0, 10))
        .order('blocked_date');
    return (rows as List)
        .map((m) => BlockedDate.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> addBlockedDate({
    required String therapistId,
    required DateTime date,
    String? reason,
  }) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await _db.from('therapist_blocked_dates').insert({
      'therapist_id': therapistId,
      'blocked_date': dateStr,
      'reason':       reason,
    });
  }

  Future<void> removeBlockedDate(String id) async {
    await _db.from('therapist_blocked_dates').delete().eq('id', id);
  }

  // ── Available slots for a specific date (patient view) ───────────────────────

  /// Returns time slots (e.g. "09:00") that are available on [date] for [therapistId].
  Future<List<String>> fetchAvailableSlotsForDate({
    required String therapistId,
    required DateTime date,
  }) async {
    // 1) What day of week is it? (Sunday=0)
    final dow = date.weekday % 7; // dart: Monday=1..Sunday=7 → mod 7 gives Sun=0

    // 2) Get availability windows for that day
    final rows = await _db
        .from('therapist_availability')
        .select()
        .eq('therapist_id', therapistId)
        .eq('day_of_week', dow)
        .eq('is_available', true);

    if ((rows as List).isEmpty) return [];

    // 3) Check blocked dates
    final dateStr = _fmt(date);
    final blocked = await _db
        .from('therapist_blocked_dates')
        .select('id')
        .eq('therapist_id', therapistId)
        .eq('blocked_date', dateStr);

    if ((blocked as List).isNotEmpty) return [];

    // 4) Get already booked confirmed/pending slots on that date
    final booked = await _db
        .from('appointments')
        .select('start_time')
        .eq('therapist_id', therapistId)
        .eq('appointment_date', dateStr)
        .inFilter('status', ['pending', 'confirmed']);

    final bookedTimes = (booked as List)
        .map((m) => (m as Map)['start_time']?.toString().substring(0, 5) ?? '')
        .toSet();

    // 5) Generate all slots from all windows
    final allSlots = <String>[];
    final now = DateTime.now();

    for (final row in rows) {
      final slot = AvailabilitySlot.fromMap(Map<String, dynamic>.from(row as Map));
      for (final time in slot.timeSlots) {
        if (bookedTimes.contains(time)) continue;

        // Disable past slots
        final slotDt = DateTime(date.year, date.month, date.day,
            int.parse(time.split(':')[0]), int.parse(time.split(':')[1]));
        if (slotDt.isBefore(now)) continue;

        if (!allSlots.contains(time)) allSlots.add(time);
      }
    }

    allSlots.sort();
    return allSlots;
  }

  /// Returns Set of dates (year-month-day) that have at least one available slot.
  Future<Set<String>> fetchAvailableDatesForMonth({
    required String therapistId,
    required int year,
    required int month,
  }) async {
    final availability = await fetchAvailability(therapistId);
    final availableDows = availability.map((a) => a.dayOfWeek).toSet();

    final blockedDates = await fetchBlockedDates(therapistId);
    final blockedSet   = blockedDates.map((b) => _fmt(b.blockedDate)).toSet();

    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final now = DateTime.now().subtract(const Duration(days: 1));

    final result = <String>{};
    for (int d = 1; d <= daysInMonth; d++) {
      final dt  = DateTime(year, month, d);
      if (dt.isBefore(now)) continue;
      final dow = dt.weekday % 7;
      final key = _fmt(dt);
      if (availableDows.contains(dow) && !blockedSet.contains(key)) {
        result.add(key);
      }
    }
    return result;
  }

  // ── Appointments ─────────────────────────────────────────────────────────────

  /// Book an appointment. Throws on double-book conflict.
  Future<AppointmentModel> bookAppointment({
    required String patientId,
    required String therapistId,
    required DateTime date,
    required String startTime, // "HH:MM"
    required String endTime,
    String? query,
  }) async {
    final endTimeFull   = '${endTime.length == 5 ? '$endTime:00' : endTime}';
    final startTimeFull = '${startTime.length == 5 ? '$startTime:00' : startTime}';

    final row = await _db.from('appointments').insert({
      'patient_id':       patientId,
      'therapist_id':     therapistId,
      'appointment_date': _fmt(date),
      'start_time':       startTimeFull,
      'end_time':         endTimeFull,
      'status':           'pending',
      'patient_query':    query,
    }).select().single();

    return AppointmentModel.fromMap(Map<String, dynamic>.from(row as Map));
  }

  /// Fetch appointments for a patient (all statuses, most recent first).
  Future<List<AppointmentModel>> fetchPatientAppointments(String patientId) async {
    final rows = await _db
        .from('appointments')
        .select('''
          *,
          profiles!therapist_id ( full_name )
        ''')
        .eq('patient_id', patientId)
        .order('appointment_date', ascending: false)
        .order('start_time', ascending: false);

    return (rows as List).map((m) {
      final map = Map<String, dynamic>.from(m as Map);
      map['therapist_name'] = (map['profiles'] as Map?)?['full_name'];
      return AppointmentModel.fromMap(map);
    }).toList();
  }

  /// Fetch appointments for a therapist.
  Future<List<AppointmentModel>> fetchTherapistAppointments(String therapistId, {String? status}) async {
    var query = _db
        .from('appointments')
        .select('''
          *,
          profiles!patient_id ( full_name )
        ''')
        .eq('therapist_id', therapistId);

    if (status != null) {
      query = query.eq('status', status);
    }

    final rows = await query
        .order('appointment_date', ascending: true)
        .order('start_time', ascending: true);

    return (rows as List).map((m) {
      final map = Map<String, dynamic>.from(m as Map);
      map['patient_name'] = (map['profiles'] as Map?)?['full_name'];
      return AppointmentModel.fromMap(map);
    }).toList();
  }

  /// Accept a booking (therapist).
  Future<void> acceptAppointment(String id, {String? notes}) async {
    await _db.from('appointments').update({
      'status':           'confirmed',
      'therapist_notes':  notes,
    }).eq('id', id);
  }

  /// Reject a booking (therapist).
  Future<void> rejectAppointment(String id, {String? reason}) async {
    await _db.from('appointments').update({
      'status':           'rejected',
      'therapist_notes':  reason,
    }).eq('id', id);
  }

  /// Cancel an appointment (either side).
  Future<void> cancelAppointment(String id, {required String cancelledBy, String? reason}) async {
    await _db.from('appointments').update({
      'status':               'cancelled',
      'cancelled_by':         cancelledBy,
      'cancellation_reason':  reason,
    }).eq('id', id);
  }

  // ── Notifications ─────────────────────────────────────────────────────────────

  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    final rows = await _db
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(30);

    return (rows as List)
        .map((m) => NotificationModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<int> fetchUnreadCount(String userId) async {
    final rows = await _db
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (rows as List).length;
  }

  Future<void> markNotificationRead(String id) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllNotificationsRead(String userId) async {
    await _db.from('notifications').update({'is_read': true}).eq('user_id', userId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Dart equivalent of DateUtils for days in month (no Flutter import needed here)
class DateUtils {
  static int getDaysInMonth(int year, int month) {
    if (month == 12) return DateTime(year + 1, 1, 0).day;
    return DateTime(year, month + 1, 0).day;
  }
}