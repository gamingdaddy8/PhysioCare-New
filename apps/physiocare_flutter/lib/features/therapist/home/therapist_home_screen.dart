import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routes/app_routes.dart';
import '../patient_details/therapist_patient_detail_screen.dart';

class TherapistHomeScreen extends StatefulWidget {
  const TherapistHomeScreen({super.key});

  static const Color kPrimary = Color(0xFF1FC7B6);
  static const Color kDark = Color(0xFF0F172A);
  static const Color kSub = Color(0xFF64748B);
  static const Color kBg = Color(0xFFF1F5F9);

  @override
  State<TherapistHomeScreen> createState() => _TherapistHomeScreenState();
}

class _TherapistHomeScreenState extends State<TherapistHomeScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  String _status = "Loading...";

  String _therapistName = "Therapist";

  List<Map<String, dynamic>> _patients = [];

  @override
  void initState() {
    super.initState();
    _loadTherapistAndPatients();
  }

  Future<void> _loadTherapistAndPatients() async {
    try {
      setState(() {
        _loading = true;
        _status = "Fetching therapist profile...";
      });

      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _loading = false;
          _status = "Not logged in.";
        });
        return;
      }

      // 1) Therapist profile
      final therapistProfile = await _supabase
          .from("profiles")
          .select()
          .eq("id", user.id)
          .maybeSingle();

      if (therapistProfile == null) {
        setState(() {
          _loading = false;
          _status = "Therapist profile not found in profiles table.";
        });
        return;
      }

      final role = therapistProfile["role"] ?? "";
      if (role != "therapist") {
        setState(() {
          _loading = false;
          _status = "You are not logged in as therapist.";
        });
        return;
      }

      _therapistName = therapistProfile["full_name"] ?? "Therapist";

      setState(() {
        _status = "Fetching assigned patients...";
      });

      // 2) Patients assigned to this therapist
      final patients = await _supabase
          .from("profiles")
          .select()
          .eq("role", "patient")
          .eq("assigned_therapist_id", user.id)
          .order("created_at", ascending: false);

      setState(() {
        _patients = List<Map<String, dynamic>>.from(patients);
        _loading = false;
        _status = "Loaded successfully ✅";
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isWeb = w >= 900;

    return Scaffold(
      backgroundColor: TherapistHomeScreen.kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Therapist Dashboard",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: TherapistHomeScreen.kDark,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _loadTherapistAndPatients,
            icon: const Icon(Icons.refresh, color: TherapistHomeScreen.kDark),
          ),
          IconButton(
            tooltip: "Logout",
            onPressed: () async {
              await _supabase.auth.signOut();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (_) => false,
              );
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
                    Text(
                      _status,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: TherapistHomeScreen.kSub,
                      ),
                    )
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
                        _HeaderCard(name: _therapistName),
                        const SizedBox(height: 18),

                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _MiniStatCard(
                              title: "Patients",
                              value: _patients.length.toString(),
                              icon: Icons.people_alt_rounded,
                            ),
                            const _MiniStatCard(
                              title: "Pain Alerts",
                              value: "0",
                              icon: Icons.warning_rounded,
                            ),
                            const _MiniStatCard(
                              title: "Sessions",
                              value: "0",
                              icon: Icons.bar_chart_rounded,
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                "Your Patients",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: TherapistHomeScreen.kDark,
                                ),
                              ),
                            ),
                            Text(
                              _status,
                              style: const TextStyle(
                                color: TherapistHomeScreen.kSub,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          ],
                        ),

                        const SizedBox(height: 12),

                        if (_patients.isEmpty)
                          const _EmptyStateCard(
                            text:
                                "No patients assigned yet.\nAssign patients by setting assigned_therapist_id in profiles.",
                          )
                        else if (isWeb)
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: _patients
                                .map(
                                  (p) => SizedBox(
                                    width: 360,
                                    child: _PatientCard(
                                      name: p["full_name"] ?? "Patient",
                                      condition: "Rehab",
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                TherapistPatientDetailScreen(
                                              patientId: p["id"].toString(),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                )
                                .toList(),
                          )
                        else
                          Column(
                            children: _patients
                                .map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _PatientCard(
                                      name: p["full_name"] ?? "Patient",
                                      condition: "Rehab",
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                TherapistPatientDetailScreen(
                                              patientId: p["id"].toString(),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                )
                                .toList(),
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

class _HeaderCard extends StatelessWidget {
  final String name;
  const _HeaderCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            TherapistHomeScreen.kPrimary,
            Color(0xFF14B8A6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
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
                const Text(
                  "Welcome Back 👋",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  "Online",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
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
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: TherapistHomeScreen.kPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: TherapistHomeScreen.kPrimary),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: TherapistHomeScreen.kSub,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: TherapistHomeScreen.kDark,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final String name;
  final String condition;
  final VoidCallback onTap;

  const _PatientCard({
    required this.name,
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
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
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
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: TherapistHomeScreen.kDark,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    condition,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: TherapistHomeScreen.kSub,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

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
        border: Border.all(color: Colors.black12.withOpacity(0.08)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: TherapistHomeScreen.kSub,
          height: 1.5,
        ),
      ),
    );
  }
}