import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routes/app_routes.dart';
import '../../../data/services/therapist_service.dart';
import '../patient_details/therapist_patient_detail_screen.dart';

class TherapistHomeScreen extends StatefulWidget {
  const TherapistHomeScreen({super.key});

  static const Color kPrimary = Color(0xFF1FC7B6);
  static const Color kDark    = Color(0xFF0F172A);
  static const Color kSub     = Color(0xFF64748B);
  static const Color kBg      = Color(0xFFF1F5F9);

  @override
  State<TherapistHomeScreen> createState() => _TherapistHomeScreenState();
}

class _TherapistHomeScreenState extends State<TherapistHomeScreen> {
  final SupabaseClient    _supabase         = Supabase.instance.client;
  final TherapistService  _therapistService = TherapistService();

  bool   _loading   = true;
  String _status    = 'Loading...';

  String _therapistName      = 'Therapist';
  String _therapistDisplayId = '';

  // Full patient list (from Supabase)
  List<Map<String, dynamic>> _patients = [];
  // Filtered list (shown in UI)
  List<Map<String, dynamic>> _filtered = [];

  int _pendingAlerts  = 0;
  int _totalSessions  = 0;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTherapistAndPatients();
    _searchCtrl.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applySearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Search / filter ───────────────────────────────────────────

  void _applySearch() {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filtered = List.from(_patients));
      return;
    }
    setState(() {
      _filtered = _patients.where((p) {
        final name = (p['full_name'] ?? '').toString().toLowerCase();
        final id   = (p['display_id'] ?? '').toString().toLowerCase();
        return name.contains(query) || id.contains(query);
      }).toList();
    });
  }

  // ── Data loading ──────────────────────────────────────────────

  Future<void> _loadTherapistAndPatients() async {
    try {
      setState(() {
        _loading = true;
        _status  = 'Fetching therapist profile...';
      });

      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() { _loading = false; _status = 'Not logged in.'; });
        return;
      }

      // 1) Therapist profile (include display_id)
      final therapistProfile = await _supabase
          .from('profiles')
          .select('full_name, role, display_id')
          .eq('id', user.id)
          .maybeSingle();

      if (therapistProfile == null) {
        setState(() { _loading = false; _status = 'Profile not found.'; });
        return;
      }

      if ((therapistProfile['role'] ?? '') != 'therapist') {
        setState(() { _loading = false; _status = 'Not a therapist account.'; });
        return;
      }

      _therapistName      = therapistProfile['full_name']  ?? 'Therapist';
      _therapistDisplayId = therapistProfile['display_id'] ?? '';

      setState(() => _status = 'Fetching patients & stats...');

      // 2) Patients assigned to this therapist (include display_id)
      final patients = await _supabase
          .from('profiles')
          .select('id, full_name, display_id, condition, created_at')
          .eq('role', 'patient')
          .eq('assigned_therapist_id', user.id)
          .order('created_at', ascending: false);

      final patientList = List<Map<String, dynamic>>.from(patients);

      // 3) Pain alerts (pending only)
      final alerts = await _therapistService.fetchPainAlerts(user.id);

      // 4) Total sessions across all patients
      int totalSessions = 0;
      for (final p in patientList) {
        final pid = p['id']?.toString();
        if (pid == null) continue;
        final sessions = await _supabase
            .from('session_reports')
            .select('id')
            .eq('patient_id', pid);
        totalSessions += (sessions as List).length;
      }

      setState(() {
        _patients       = patientList;
        _filtered       = List.from(patientList);
        _pendingAlerts  = alerts.length;
        _totalSessions  = totalSessions;
        _loading        = false;
        _status         = 'Loaded successfully ✅';
      });

      // Re-apply any existing search text after reload
      _applySearch();
    } catch (e) {
      setState(() { _loading = false; _status = 'Error: $e'; });
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w     = MediaQuery.sizeOf(context).width;
    final isWeb = w >= 900;

    return Scaffold(
      backgroundColor: TherapistHomeScreen.kBg,
      appBar: AppBar(
        backgroundColor:  Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Therapist Dashboard',
          style: TextStyle(
              fontWeight: FontWeight.w900,
              color: TherapistHomeScreen.kDark),
        ),
        actions: [
          IconButton(
            tooltip:  'Refresh',
            onPressed: _loadTherapistAndPatients,
            icon: const Icon(Icons.refresh, color: TherapistHomeScreen.kDark),
          ),
          IconButton(
            tooltip:  'Logout',
            onPressed: () async {
              await _supabase.auth.signOut();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, AppRoutes.login, (_) => false);
            },
            icon: const Icon(Icons.logout, color: TherapistHomeScreen.kDark),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 14),
                    Text(_status,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: TherapistHomeScreen.kSub)),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header card with therapist ID ─────────
                        _HeaderCard(
                          name:      _therapistName,
                          displayId: _therapistDisplayId,
                        ),
                        const SizedBox(height: 18),

                        // ── Stat chips ────────────────────────────
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _MiniStatCard(
                              title: 'Patients',
                              value: _patients.length.toString(),
                              icon:  Icons.people_alt_rounded,
                            ),
                            _MiniStatCard(
                              title: 'Pain Alerts',
                              value: _pendingAlerts.toString(),
                              icon:  Icons.warning_rounded,
                            ),
                            _MiniStatCard(
                              title: 'Sessions',
                              value: _totalSessions.toString(),
                              icon:  Icons.bar_chart_rounded,
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // ── Section title + status ────────────────
                        Row(children: [
                          const Expanded(
                            child: Text(
                              'Your Patients',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: TherapistHomeScreen.kDark),
                            ),
                          ),
                          Text(_status,
                              style: const TextStyle(
                                  color: TherapistHomeScreen.kSub,
                                  fontWeight: FontWeight.w700)),
                        ]),

                        const SizedBox(height: 12),

                        // ── Search bar ────────────────────────────
                        _SearchBar(controller: _searchCtrl),

                        const SizedBox(height: 12),

                        // ── Patient list / grid ───────────────────
                        if (_patients.isEmpty)
                          const _EmptyStateCard(
                            text:
                                'No patients assigned yet.\nPatients choose you during registration.',
                          )
                        else if (_filtered.isEmpty)
                          _NoResultsCard(query: _searchCtrl.text.trim())
                        else if (isWeb)
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: _filtered.map((p) => SizedBox(
                              width: 360,
                              child: _PatientCard(
                                name:      p['full_name'] ?? 'Patient',
                                displayId: p['display_id'] ?? '',
                                condition: p['condition'] ?? 'Rehab',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TherapistPatientDetailScreen(
                                      patientId: p['id'].toString(),
                                    ),
                                  ),
                                ),
                              ),
                            )).toList(),
                          )
                        else
                          Column(
                            children: _filtered.map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PatientCard(
                                name:      p['full_name'] ?? 'Patient',
                                displayId: p['display_id'] ?? '',
                                condition: p['condition'] ?? 'Rehab',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TherapistPatientDetailScreen(
                                      patientId: p['id'].toString(),
                                    ),
                                  ),
                                ),
                              ),
                            )).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText:    'Search by name or ID (e.g. PT-00123)...',
        hintStyle:   const TextStyle(color: TherapistHomeScreen.kSub),
        prefixIcon:  const Icon(Icons.search,
            color: TherapistHomeScreen.kSub),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear,
                    color: TherapistHomeScreen.kSub, size: 18),
                onPressed: () => controller.clear(),
              )
            : null,
        filled:      true,
        fillColor:   Colors.white,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: TherapistHomeScreen.kPrimary, width: 1.5),
        ),
      ),
    );
  }
}

// ── Header card ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final String name;
  final String displayId;
  const _HeaderCard({required this.name, required this.displayId});

  void _copyId(BuildContext context) {
    if (displayId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: displayId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$displayId copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [
          TherapistHomeScreen.kPrimary,
          Color(0xFF14B8A6),
        ]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: Colors.white,
          child: Icon(Icons.medical_services,
              color: TherapistHomeScreen.kPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome Back 👋',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20)),
              if (displayId.isNotEmpty) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _copyId(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.badge_outlined,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              displayId,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 1.1),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.copy_outlined,
                                color: Colors.white70, size: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.white.withOpacity(0.25)),
          ),
          child: const Row(children: [
            Icon(Icons.verified, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Online',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
      ]),
    );
  }
}

// ── Mini stat card ────────────────────────────────────────────────────────────

class _MiniStatCard extends StatelessWidget {
  final String  title;
  final String  value;
  final IconData icon;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 4))
        ],
      ),
      child: Row(children: [
        Container(
          height: 46,
          width:  46,
          decoration: BoxDecoration(
            color: TherapistHomeScreen.kPrimary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: TherapistHomeScreen.kPrimary),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: TherapistHomeScreen.kSub,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: TherapistHomeScreen.kDark)),
        ]),
      ]),
    );
  }
}

// ── Patient card (now shows display_id badge) ─────────────────────────────────

class _PatientCard extends StatelessWidget {
  final String     name;
  final String     displayId;
  final String     condition;
  final VoidCallback onTap;

  const _PatientCard({
    required this.name,
    required this.displayId,
    required this.condition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, 4))
          ],
        ),
        child: Row(children: [
          Container(
            height: 52,
            width:  52,
            decoration: BoxDecoration(
              color: TherapistHomeScreen.kPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person,
                color: TherapistHomeScreen.kPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: TherapistHomeScreen.kDark,
                        fontSize: 16)),
                const SizedBox(height: 4),
                // ID badge
                if (displayId.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: TherapistHomeScreen.kPrimary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      displayId,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: TherapistHomeScreen.kPrimary,
                          letterSpacing: 0.8),
                    ),
                  ),
                Text(condition,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: TherapistHomeScreen.kSub,
                        fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}

// ── Empty / no-results states ─────────────────────────────────────────────────

class _EmptyStateCard extends StatelessWidget {
  final String text;
  const _EmptyStateCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Colors.black12.withOpacity(0.08)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: TherapistHomeScreen.kSub,
              height: 1.5)),
    );
  }
}

class _NoResultsCard extends StatelessWidget {
  final String query;
  const _NoResultsCard({required this.query});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(children: [
        const Icon(Icons.search_off,
            size: 40, color: TherapistHomeScreen.kSub),
        const SizedBox(height: 10),
        Text(
          'No patients match "$query"',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: TherapistHomeScreen.kDark,
              fontSize: 15),
        ),
        const SizedBox(height: 6),
        const Text(
          'Try searching by full name or patient ID (e.g. PT-00123)',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: TherapistHomeScreen.kSub, fontSize: 13),
        ),
      ]),
    );
  }
}