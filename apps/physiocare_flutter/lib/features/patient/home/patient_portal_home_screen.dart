import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routes/app_routes.dart';
import '../../appointments/screens/notifications_screen.dart';

class PatientPortalHomeScreen extends StatefulWidget {
  const PatientPortalHomeScreen({super.key});

  @override
  State<PatientPortalHomeScreen> createState() =>
      _PatientPortalHomeScreenState();
}

class _PatientPortalHomeScreenState extends State<PatientPortalHomeScreen> {
  static const Color kPrimary = Color(0xFF1FC7B6);
  static const Color kBg = Color(0xFFF8FAFC);
  static const Color kTextDark = Color(0xFF0F172A);
  static const Color kSub = Color(0xFF64748B);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  String _patientName = "there";
  List<Map<String, dynamic>> _assignedExercises = [];
  int _completedToday = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1) Fetch patient profile
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        _patientName = profile['full_name'] ?? 'there';
      }

      // 2) Fetch assigned exercises (active ones)
      final assigned = await _supabase
          .from('assigned_exercises')
          .select('''
            id,
            reps,
            sessions_per_day,
            total_days,
            start_date,
            end_date,
            status,
            exercises ( id, title )
          ''')
          .eq('patient_id', user.id)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      _assignedExercises = List<Map<String, dynamic>>.from(assigned);

      // 3) Count sessions completed today
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final sessions = await _supabase
          .from('session_reports')
          .select('id')
          .eq('patient_id', user.id)
          .gte('created_at', '${todayStr}T00:00:00')
          .lte('created_at', '${todayStr}T23:59:59');

      _completedToday = (sessions as List).length;
    } catch (e) {
      debugPrint('PatientPortalHomeScreen load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reportPain(int level, String note) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('pain_reports').insert({
        'patient_id': user.id,
        'pain_level': level,
        'description': note,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pain report submitted. Your therapist has been notified.'),
          backgroundColor: Color(0xFF1FC7B6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit pain report: $e')),
      );
    }
  }

  void _showPainDialog() {
    int selectedLevel = 5;
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Report Pain',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pain level (1 = mild, 10 = severe)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: selectedLevel.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: const Color(0xFFE53935),
                      label: selectedLevel.toString(),
                      onChanged: (v) =>
                          setDialogState(() => selectedLevel = v.round()),
                    ),
                  ),
                  Text(
                    '$selectedLevel',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Additional notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _reportPain(selectedLevel, noteCtrl.text.trim());
              },
              child: const Text('Submit',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.splash, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 900;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 18,
        title: const _TopTitle(),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Color(0xFF0F172A)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Greeting(name: _patientName),
                        const SizedBox(height: 18),

                        _TodaySessionCard(
                          isWide: isWide,
                          completedToday: _completedToday,
                          assignedCount: _assignedExercises.length,
                        ),
                        const SizedBox(height: 18),

                        _QuickActionsRow(isWide: isWide),
                        const SizedBox(height: 18),

                        Row(
                          children: [
                            const Text(
                              'Your Exercises',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: kTextDark,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                  context, AppRoutes.patientExercises),
                              icon: const Icon(Icons.chevron_right),
                              label: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        _assignedExercises.isEmpty
                            ? _EmptyExercisesCard(
                                isWide: isWide,
                                onReportPain: _showPainDialog,
                              )
                            : _ExercisesList(
                                exercises: _assignedExercises,
                                isWide: isWide,
                                onReportPain: _showPainDialog,
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

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _TopTitle extends StatelessWidget {
  const _TopTitle();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFF1FC7B6),
          child: Icon(Icons.monitor_heart, color: Colors.white, size: 18),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PhysioCare',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Patient Portal',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  final String name;
  const _Greeting({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, $name!',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Let's continue your recovery journey today.",
          style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class _TodaySessionCard extends StatelessWidget {
  final bool isWide;
  final int completedToday;
  final int assignedCount;

  const _TodaySessionCard({
    required this.isWide,
    required this.completedToday,
    required this.assignedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF1FC7B6), Color(0xFF21C6D6)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Sessions",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  '$completedToday completed',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  '$assignedCount exercise${assignedCount == 1 ? '' : 's'} assigned to you',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.95), fontSize: 14),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: assignedCount == 0
                        ? null
                        : () => Navigator.pushNamed(
                            context, AppRoutes.exerciseSession),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Session',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.trending_up, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final bool isWide;
  const _QuickActionsRow({required this.isWide});

  @override
  Widget build(BuildContext context) {
    const cards = [
      _QuickActionCard(
          title: 'Exercises',
          icon: Icons.play_arrow,
          route: AppRoutes.patientExercises),
      _QuickActionCard(
          title: 'Reports',
          icon: Icons.description_outlined,
          route: AppRoutes.patientReport),
      _QuickActionCard(
          title: 'Appointments',
          icon: Icons.calendar_month,
          route: AppRoutes.myAppointments),
    ];

    if (isWide) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 14),
          Expanded(child: cards[1]),
          const SizedBox(width: 14),
          Expanded(child: cards[2]),
        ],
      );
    }

    return Column(children: [
      cards[0],
      const SizedBox(height: 12),
      cards[1],
      const SizedBox(height: 12),
      cards[2],
    ]);
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF1FC7B6)),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// Shows real assigned exercises from Supabase
class _ExercisesList extends StatelessWidget {
  final List<Map<String, dynamic>> exercises;
  final bool isWide;
  final VoidCallback onReportPain;

  const _ExercisesList({
    required this.exercises,
    required this.isWide,
    required this.onReportPain,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...exercises.map((ex) {
          final title = ex['exercises']?['title'] ?? 'Exercise';
          final reps = ex['reps'] ?? 0;
          final exerciseId = ex['exercises']?['id']?.toString() ?? '';
          final assignedId = ex['id']?.toString() ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ExerciseCard(
              title: title,
              reps: reps,
              onStart: () => Navigator.pushNamed(
                context,
                AppRoutes.exerciseSession,
                arguments: {
                  'assigned_exercise_id': assignedId,
                  'exercise_id': exerciseId,
                  'title': title,
                  'reps': reps,
                },
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: _ReportPainButton(onPressed: onReportPain),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final String title;
  final int reps;
  final VoidCallback onStart;

  const _ExerciseCard({
    required this.title,
    required this.reps,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF1FC7B6).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.fitness_center, color: Color(0xFF1FC7B6)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text('$reps reps',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF64748B))),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1FC7B6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onStart,
            child: const Text('Start',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _EmptyExercisesCard extends StatelessWidget {
  final bool isWide;
  final VoidCallback onReportPain;

  const _EmptyExercisesCard({
    required this.isWide,
    required this.onReportPain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: isWide
          ? Row(
              children: [
                const Expanded(child: _EmptyText()),
                const SizedBox(width: 18),
                _ReportPainButton(onPressed: onReportPain),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _EmptyText(),
                const SizedBox(height: 14),
                SizedBox(
                    width: double.infinity,
                    child: _ReportPainButton(onPressed: onReportPain)),
              ],
            ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.monitor_heart_outlined,
            size: 40, color: Color(0xFF64748B)),
        SizedBox(height: 10),
        Text(
          'No exercises assigned yet',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A)),
        ),
        SizedBox(height: 6),
        Text(
          'Your physiotherapist will assign exercises for your recovery plan.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class _ReportPainButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ReportPainButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.error_outline),
      label: const Text('Report Pain',
          style: TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}