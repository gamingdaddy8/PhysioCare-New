// ── Appointment Models ────────────────────────────────────────────────────────

enum AppointmentStatus { pending, confirmed, rejected, cancelled }

extension AppointmentStatusX on AppointmentStatus {
  String get label {
    switch (this) {
      case AppointmentStatus.pending:   return 'Pending';
      case AppointmentStatus.confirmed: return 'Confirmed';
      case AppointmentStatus.rejected:  return 'Rejected';
      case AppointmentStatus.cancelled: return 'Cancelled';
    }
  }

  String get dbValue {
    switch (this) {
      case AppointmentStatus.pending:   return 'pending';
      case AppointmentStatus.confirmed: return 'confirmed';
      case AppointmentStatus.rejected:  return 'rejected';
      case AppointmentStatus.cancelled: return 'cancelled';
    }
  }

  static AppointmentStatus fromString(String s) {
    switch (s) {
      case 'confirmed': return AppointmentStatus.confirmed;
      case 'rejected':  return AppointmentStatus.rejected;
      case 'cancelled': return AppointmentStatus.cancelled;
      default:          return AppointmentStatus.pending;
    }
  }
}

class AppointmentModel {
  final String id;
  final String patientId;
  final String therapistId;
  final DateTime appointmentDate;
  final String startTime; // "HH:MM"
  final String endTime;
  final AppointmentStatus status;
  final String? patientQuery;
  final String? therapistNotes;
  final String? cancelledBy;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields (populated by service)
  final String? patientName;
  final String? therapistName;

  const AppointmentModel({
    required this.id,
    required this.patientId,
    required this.therapistId,
    required this.appointmentDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.patientQuery,
    this.therapistNotes,
    this.cancelledBy,
    this.cancellationReason,
    required this.createdAt,
    required this.updatedAt,
    this.patientName,
    this.therapistName,
  });

  factory AppointmentModel.fromMap(Map<String, dynamic> m) {
    return AppointmentModel(
      id:              m['id']?.toString() ?? '',
      patientId:       m['patient_id']?.toString() ?? '',
      therapistId:     m['therapist_id']?.toString() ?? '',
      appointmentDate: DateTime.tryParse(m['appointment_date']?.toString() ?? '') ?? DateTime.now(),
      startTime:       m['start_time']?.toString() ?? '',
      endTime:         m['end_time']?.toString() ?? '',
      status:          AppointmentStatusX.fromString(m['status']?.toString() ?? ''),
      patientQuery:    m['patient_query']?.toString(),
      therapistNotes:  m['therapist_notes']?.toString(),
      cancelledBy:     m['cancelled_by']?.toString(),
      cancellationReason: m['cancellation_reason']?.toString(),
      createdAt:       DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt:       DateTime.tryParse(m['updated_at']?.toString() ?? '') ?? DateTime.now(),
      patientName:     m['patient_name']?.toString(),
      therapistName:   m['therapist_name']?.toString(),
    );
  }

  String get formattedDate {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${appointmentDate.day} ${months[appointmentDate.month]} ${appointmentDate.year}';
  }

  String get formattedTime {
    // Convert "14:30:00" → "2:30 PM"
    final parts = startTime.split(':');
    if (parts.length < 2) return startTime;
    int h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final suffix = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '$h:$m $suffix';
  }
}

class AvailabilitySlot {
  final String id;
  final String therapistId;
  final int dayOfWeek; // 0=Sunday, 1=Monday ... 6=Saturday
  final String startTime; // "HH:MM:SS"
  final String endTime;
  final int slotDurationMinutes;
  final bool isAvailable;

  const AvailabilitySlot({
    required this.id,
    required this.therapistId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.slotDurationMinutes,
    required this.isAvailable,
  });

  factory AvailabilitySlot.fromMap(Map<String, dynamic> m) {
    return AvailabilitySlot(
      id:                  m['id']?.toString() ?? '',
      therapistId:         m['therapist_id']?.toString() ?? '',
      dayOfWeek:           (m['day_of_week'] as num?)?.toInt() ?? 0,
      startTime:           m['start_time']?.toString() ?? '',
      endTime:             m['end_time']?.toString() ?? '',
      slotDurationMinutes: (m['slot_duration_minutes'] as num?)?.toInt() ?? 30,
      isAvailable:         m['is_available'] as bool? ?? true,
    );
  }

  String get dayName {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return dayOfWeek >= 0 && dayOfWeek < 7 ? days[dayOfWeek] : '';
  }

  /// Returns all time slot strings (e.g. ["09:00", "09:30", ...]) for this window
  List<String> get timeSlots {
    final slots = <String>[];
    final startParts = startTime.split(':');
    final endParts   = endTime.split(':');
    if (startParts.length < 2 || endParts.length < 2) return slots;

    int sh = int.tryParse(startParts[0]) ?? 0;
    int sm = int.tryParse(startParts[1]) ?? 0;
    final eh = int.tryParse(endParts[0]) ?? 0;
    final em = int.tryParse(endParts[1]) ?? 0;

    final endMinutes = eh * 60 + em;

    while (sh * 60 + sm < endMinutes) {
      slots.add('${sh.toString().padLeft(2, '0')}:${sm.toString().padLeft(2, '0')}');
      sm += slotDurationMinutes;
      sh += sm ~/ 60;
      sm = sm % 60;
    }
    return slots;
  }
}

class BlockedDate {
  final String id;
  final String therapistId;
  final DateTime blockedDate;
  final String? reason;

  const BlockedDate({
    required this.id,
    required this.therapistId,
    required this.blockedDate,
    this.reason,
  });

  factory BlockedDate.fromMap(Map<String, dynamic> m) {
    return BlockedDate(
      id:          m['id']?.toString() ?? '',
      therapistId: m['therapist_id']?.toString() ?? '',
      blockedDate: DateTime.tryParse(m['blocked_date']?.toString() ?? '') ?? DateTime.now(),
      reason:      m['reason']?.toString(),
    );
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> m) {
    return NotificationModel(
      id:          m['id']?.toString() ?? '',
      userId:      m['user_id']?.toString() ?? '',
      title:       m['title']?.toString() ?? '',
      body:        m['body']?.toString() ?? '',
      type:        m['type']?.toString() ?? '',
      referenceId: m['reference_id']?.toString(),
      isRead:      m['is_read'] as bool? ?? false,
      createdAt:   DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}