import 'package:supabase_flutter/supabase_flutter.dart';

/// Central access point for the Supabase client.
/// Use this instead of calling Supabase.instance.client directly
/// throughout the app — makes it easy to swap or mock later.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  // ── Auth shortcuts ───────────────────────────────────────────
  User?   get currentUser   => client.auth.currentUser;
  String? get currentUserId => client.auth.currentUser?.id;
  bool    get isLoggedIn    => client.auth.currentSession != null;

  Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  // ── Table helpers ────────────────────────────────────────────

  /// Quick select from any table with optional filters.
  /// Example:
  ///   final rows = await SupabaseService.instance
  ///       .select('profiles', filters: {'role': 'therapist'});
  Future<List<Map<String, dynamic>>> select(
    String table, {
    String columns = '*',
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    // Build filter query
    var filterQuery = client.from(table).select(columns);
    if (filters != null) {
      for (final entry in filters.entries) {
        filterQuery = filterQuery.eq(entry.key, entry.value);
      }
    }

    // Apply order / limit on the transform builder separately
    if (orderBy != null && limit != null) {
      final rows = await filterQuery
          .order(orderBy, ascending: ascending)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } else if (orderBy != null) {
      final rows = await filterQuery.order(orderBy, ascending: ascending);
      return List<Map<String, dynamic>>.from(rows);
    } else if (limit != null) {
      final rows = await filterQuery.limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } else {
      final rows = await filterQuery;
      return List<Map<String, dynamic>>.from(rows);
    }
  }

  /// Insert a row and return the inserted record.
  Future<Map<String, dynamic>?> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final row = await client
        .from(table)
        .insert(data)
        .select()
        .maybeSingle();
    return row;
  }

  /// Update rows matching filters.
  Future<void> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
  }) async {
    var query = client.from(table).update(data);
    for (final entry in filters.entries) {
      query = query.eq(entry.key, entry.value);
    }
    await query;
  }

  /// Delete rows matching filters.
  Future<void> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    var query = client.from(table).delete();
    for (final entry in filters.entries) {
      query = query.eq(entry.key, entry.value);
    }
    await query;
  }
}