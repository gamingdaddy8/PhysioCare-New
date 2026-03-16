import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Fetch ────────────────────────────────────────────────────

  /// Fetch the profile of the currently logged-in user.
  Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    return await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  /// Fetch any profile by user ID.
  Future<Map<String, dynamic>?> fetchProfileById(String userId) async {
    return await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  /// Fetch the role of the current user ('patient' or 'therapist').
  Future<String?> fetchCurrentRole() async {
    final profile = await fetchCurrentProfile();
    return profile?['role']?.toString();
  }

  // ── Update ───────────────────────────────────────────────────

  /// Update fields on the current user's profile.
  /// Pass only the fields you want to change.
  /// Example:
  ///   await profileService.updateCurrentProfile({'full_name': 'Jane'});
  Future<void> updateCurrentProfile(Map<String, dynamic> fields) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('profiles')
        .update(fields)
        .eq('id', userId);
  }

  /// Update contact details for the current user.
  Future<void> updateContactDetails({
    String? phone,
    String? altPhone,
    String? address,
    String? condition,
  }) async {
    final fields = <String, dynamic>{};
    if (phone     != null) fields['phone']     = phone;
    if (altPhone  != null) fields['alt_phone'] = altPhone;
    if (address   != null) fields['address']   = address;
    if (condition != null) fields['condition'] = condition;

    if (fields.isNotEmpty) {
      await updateCurrentProfile(fields);
    }
  }

  // ── Therapist assignment ─────────────────────────────────────

  /// Assign a therapist to the current patient.
  Future<void> assignTherapist(String therapistId) async {
    await updateCurrentProfile({'assigned_therapist_id': therapistId});
  }

  /// Get the therapist assigned to the current patient.
  Future<Map<String, dynamic>?> fetchAssignedTherapist() async {
    final profile = await fetchCurrentProfile();
    final therapistId = profile?['assigned_therapist_id']?.toString();
    if (therapistId == null || therapistId.isEmpty) return null;

    return await fetchProfileById(therapistId);
  }

  // ── Lists ────────────────────────────────────────────────────

  /// Fetch all therapists (for patient registration dropdown).
  Future<List<Map<String, dynamic>>> fetchAllTherapists() async {
    final rows = await _supabase
        .from('profiles')
        .select('id, full_name, specialization')
        .eq('role', 'therapist')
        .order('full_name', ascending: true);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Fetch all patients assigned to a specific therapist.
  Future<List<Map<String, dynamic>>> fetchPatientsForTherapist(
      String therapistId) async {
    final rows = await _supabase
        .from('profiles')
        .select()
        .eq('role', 'patient')
        .eq('assigned_therapist_id', therapistId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }
}