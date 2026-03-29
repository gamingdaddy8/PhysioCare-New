import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Current logged-in user
  User? get currentUser => _supabase.auth.currentUser;
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Sign in and return role
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = res.user;
    if (user == null) throw Exception('Login failed');

    // Ensure profile row exists
    final existing = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    final meta     = user.userMetadata ?? {};
    final metaRole = (meta['role'] ?? 'patient').toString();

    if (existing == null) {
      await _supabase.from('profiles').insert({
        'id':                    user.id,
        'role':                  metaRole,
        'full_name':             meta['full_name'] ?? 'Unnamed',
        'phone':                 meta['phone'],
        'alt_phone':             meta['alt_phone'],
        'address':               meta['address'],
        'assigned_therapist_id': meta['assigned_therapist_id'],
      });
    } else {
      final dbRole = (existing['role'] ?? '').toString();
      if (dbRole.isEmpty || (dbRole != 'patient' && dbRole != 'therapist')) {
        await _supabase
            .from('profiles')
            .update({'role': metaRole})
            .eq('id', user.id);
      }
    }

    // Return role as source of truth
    final profile = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();

    return (profile['role'] ?? 'patient').toString();
  }

  // Register new user
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
    String? altPhone,
    String? address,
    String? assignedTherapistId,
  }) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'role':                  role,
        'full_name':             fullName,
        'phone':                 phone,
        'alt_phone':             altPhone,
        'address':               address,
        'assigned_therapist_id': assignedTherapistId,
      },
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Fetch full profile of current user
  Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    return await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  // Check if a session is active
  bool get isLoggedIn => _supabase.auth.currentSession != null;

  // Stream auth state changes
  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;
}