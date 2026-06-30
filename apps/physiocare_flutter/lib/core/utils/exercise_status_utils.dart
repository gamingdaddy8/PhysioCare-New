/// Derives the real-world status of an assigned exercise from its dates,
/// falling back to the stored DB value only for non-date states like 'paused'.
String effectiveExerciseStatus(Map<String, dynamic> exercise) {
  final raw = (exercise['status'] ?? '').toString();
  if (raw == 'paused') return 'paused';

  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);

  final endStr = exercise['end_date']?.toString();
  if (endStr != null && endStr.isNotEmpty) {
    final end = DateTime.tryParse(endStr);
    if (end != null && todayOnly.isAfter(end)) return 'completed';
  }

  final startStr = exercise['start_date']?.toString();
  if (startStr != null && startStr.isNotEmpty) {
    final start = DateTime.tryParse(startStr);
    if (start != null && todayOnly.isBefore(start)) return 'upcoming';
  }

  return raw.isEmpty ? 'active' : raw;
}
