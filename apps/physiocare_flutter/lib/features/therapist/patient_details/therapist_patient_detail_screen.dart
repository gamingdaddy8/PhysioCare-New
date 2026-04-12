import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routes/app_routes.dart';

class TherapistPatientDetailScreen extends StatefulWidget {
  final String patientId;

  const TherapistPatientDetailScreen({
    super.key,
    required this.patientId,
  });

  static const Color kPrimary = Color(0xFF1FC7B6);
  static const Color kDark    = Color(0xFF0F172A);
  static const Color kSub     = Color(0xFF64748B);
  static const Color kBg      = Color(0xFFF1F5F9);

  @override
  State<TherapistPatientDetailScreen> createState() =>
      _TherapistPatientDetailScreenState();
}

class _TherapistPatientDetailScreenState
    extends State<TherapistPatientDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool   _loading = true;
  String _status  = 'Loading...';

  String  patientName  = 'Patient';
  String  condition    = 'Rehab';
  String? patientEmail;
  String? phone;
  String? altPhone;
  String? address;

  List<Map<String, dynamic>> _exercises      = [];
  List<Map<String, dynamic>> _assigned       = [];
  List<Map<String, dynamic>> _sessionReports = [];
  List<Map<String, dynamic>> _feedbackList   = [];

  final TextEditingController _feedbackCtrl = TextEditingController();

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  // ── Load all data ─────────────────────────────────────────────

  Future<void> _loadAll() async {
    try {
      setState(() {
        _loading = true;
        _status  = 'Loading patient...';
      });

      // 1) Patient profile
      final patientProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', widget.patientId)
          .maybeSingle();

      if (patientProfile != null) {
        patientName  = patientProfile['full_name'] ?? 'Patient';
        condition    = patientProfile['condition']  ?? 'Rehab';
        patientEmail = patientProfile['email'];
        phone        = patientProfile['phone'];
        altPhone     = patientProfile['alt_phone'];
        address      = patientProfile['address'];
      }

      // 2) Exercise master list
      setState(() => _status = 'Loading exercises...');
      final exercises = await _supabase
          .from('exercises')
          .select()
          .order('title');
      _exercises = List<Map<String, dynamic>>.from(exercises);

      // 3) Assigned exercises
      await _loadAssignedExercises();

      // 4) Session reports
      await _loadSessionReports();

      // 5) Feedback
      await _loadFeedback();

      setState(() {
        _loading = false;
        _status  = 'Loaded ✅';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status  = 'Error: $e';
      });
    }
  }

  Future<void> _loadAssignedExercises() async {
    try {
      final therapistId = _supabase.auth.currentUser?.id;
      if (therapistId == null) return;

      setState(() => _status = 'Loading assigned exercises...');

      final rows = await _supabase
          .from('assigned_exercises')
          .select('''
            id,
            reps,
            total_days,
            sessions_per_day,
            start_date,
            end_date,
            status,
            created_at,
            exercises ( title )
          ''')
          .eq('patient_id', widget.patientId)
          .eq('therapist_id', therapistId)
          .order('created_at', ascending: false);

      setState(() => _assigned = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      debugPrint('Error loading assigned: $e');
    }
  }

  Future<void> _loadSessionReports() async {
    try {
      final rows = await _supabase
          .from('session_reports')
          .select('''
            id,
            reps_done,
            duration_seconds,
            notes,
            exercise_title,
            created_at
          ''')
          .eq('patient_id', widget.patientId)
          .order('created_at', ascending: false)
          .limit(10);

      setState(() =>
          _sessionReports = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    }
  }

  Future<void> _loadFeedback() async {
    try {
      final therapistId = _supabase.auth.currentUser?.id;
      if (therapistId == null) return;

      final rows = await _supabase
          .from('therapist_feedback')
          .select()
          .eq('patient_id', widget.patientId)
          .eq('therapist_id', therapistId)
          .order('created_at', ascending: false)
          .limit(20);

      setState(() =>
          _feedbackList = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      debugPrint('Error loading feedback: $e');
    }
  }

  // ── Actions ───────────────────────────────────────────────────

  Future<void> _assignExercise({
    required String exerciseId,
    required int reps,
    required int totalDays,
    required int sessionsPerDay,
  }) async {
    final therapistId = _supabase.auth.currentUser?.id;
    if (therapistId == null) return;

    final startDate = DateTime.now();
    final endDate   = startDate.add(Duration(days: totalDays - 1));

    final fmt = (DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    await _supabase.from('assigned_exercises').insert({
      'patient_id':       widget.patientId,
      'therapist_id':     therapistId,
      'exercise_id':      exerciseId,
      'reps':             reps,
      'total_days':       totalDays,
      'sessions_per_day': sessionsPerDay,
      'start_date':       fmt(startDate),
      'end_date':         fmt(endDate),
      'status':           'active',
    });

    await _loadAssignedExercises();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exercise assigned successfully ✅')),
    );
    setState(() {});
  }

  Future<void> _sendFeedback() async {
    final text = _feedbackCtrl.text.trim();
    if (text.isEmpty) return;

    final therapistId = _supabase.auth.currentUser?.id;
    if (therapistId == null) return;

    try {
      await _supabase.from('therapist_feedback').insert({
        'patient_id':   widget.patientId,
        'therapist_id': therapistId,
        'message':      text,
        'created_at':   DateTime.now().toIso8601String(),
      });

      _feedbackCtrl.clear();
      await _loadFeedback();
      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback sent ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send feedback: $e')),
      );
    }
  }

  void _openAddExerciseDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddExerciseDialog(
        exercises: _exercises,
        onAssign: (exerciseId, reps, totalDays, sessionsPerDay) async {
          Navigator.pop(context);
          await _assignExercise(
            exerciseId:      exerciseId,
            reps:            reps,
            totalDays:       totalDays,
            sessionsPerDay:  sessionsPerDay,
          );
        },
      ),
    );
  }

  void _navigateToReport() {
    Navigator.pushNamed(
      context,
      AppRoutes.therapistReport,
      arguments: {
        'patientId':   widget.patientId,
        'patientName': patientName,
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w     = MediaQuery.sizeOf(context).width;
    final isWeb = w >= 900;

    return Scaffold(
      backgroundColor: TherapistPatientDetailScreen.kBg,
      appBar: AppBar(
        backgroundColor:   Colors.white,
        surfaceTintColor:  Colors.white,
        elevation: 0,
        title: const Text(
          'Patient Details',
          style: TextStyle(
              fontWeight: FontWeight.w900,
              color: TherapistPatientDetailScreen.kDark),
        ),
        iconTheme: const IconThemeData(
            color: TherapistPatientDetailScreen.kDark),
        actions: [
          // ── NEW: Report shortcut in app bar ──
          IconButton(
            tooltip:  'View Full Report',
            onPressed: _navigateToReport,
            icon: const Icon(
              Icons.assessment_outlined,
              color: TherapistPatientDetailScreen.kPrimary,
            ),
          ),
          IconButton(
            tooltip:  'Refresh',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh,
                color: TherapistPatientDetailScreen.kDark),
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
                            color: TherapistPatientDetailScreen.kSub)),
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
                        _PatientHeaderCard(
                            name: patientName, condition: condition),
                        const SizedBox(height: 18),

                        // ── Stats row ──
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _MiniStatCard(
                              title: 'Assigned',
                              value: _assigned.length.toString(),
                              icon:  Icons.fitness_center,
                            ),
                            _MiniStatCard(
                              title: 'Sessions',
                              value: _sessionReports.length.toString(),
                              icon:  Icons.bar_chart_rounded,
                            ),
                            const _MiniStatCard(
                              title: 'Pain Alerts',
                              value: '0',
                              icon:  Icons.warning_rounded,
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ── NEW: View Full Report button ──
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  TherapistPatientDetailScreen.kPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _navigateToReport,
                            icon: const Icon(Icons.assessment_outlined),
                            label: const Text(
                              'View Full Report & Analytics',
                              style:
                                  TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ── Main content ──
                        if (isWeb)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(children: [
                                  _AssignedExercisesCard(
                                    assigned: _assigned,
                                    onAdd:    _openAddExerciseDialog,
                                  ),
                                  const SizedBox(height: 18),
                                  _RecentSessionsCard(
                                      sessions: _sessionReports),
                                ]),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                flex: 4,
                                child: Column(children: [
                                  _FeedbackCard(
                                    feedbackList: _feedbackList,
                                    controller:   _feedbackCtrl,
                                    onSend:       _sendFeedback,
                                  ),
                                  const SizedBox(height: 18),
                                  _ContactCard(
                                    phone:    phone,
                                    altPhone: altPhone,
                                    address:  address,
                                  ),
                                ]),
                              ),
                            ],
                          )
                        else
                          Column(children: [
                            _AssignedExercisesCard(
                              assigned: _assigned,
                              onAdd:    _openAddExerciseDialog,
                            ),
                            const SizedBox(height: 18),
                            _RecentSessionsCard(sessions: _sessionReports),
                            const SizedBox(height: 18),
                            _FeedbackCard(
                              feedbackList: _feedbackList,
                              controller:   _feedbackCtrl,
                              onSend:       _sendFeedback,
                            ),
                            const SizedBox(height: 18),
                            _ContactCard(
                              phone:    phone,
                              altPhone: altPhone,
                              address:  address,
                            ),
                          ]),

                        const SizedBox(height: 12),
                        Text(_status,
                            style: const TextStyle(
                                color: TherapistPatientDetailScreen.kSub,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PatientHeaderCard extends StatelessWidget {
  final String name;
  final String condition;
  const _PatientHeaderCard({required this.name, required this.condition});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [
          TherapistPatientDetailScreen.kPrimary,
          Color(0xFF14B8A6),
        ]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: Colors.white,
          child: Icon(Icons.person,
              color: TherapistPatientDetailScreen.kPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20)),
              const SizedBox(height: 4),
              Text(condition,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600)),
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
          child: const Row(children: [
            Icon(Icons.verified, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Active',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
          ]),
        ),
      ]),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String  title;
  final String  value;
  final IconData icon;
  const _MiniStatCard(
      {required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Row(children: [
        Container(
          height: 46,
          width:  46,
          decoration: BoxDecoration(
            color: TherapistPatientDetailScreen.kPrimary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: TherapistPatientDetailScreen.kPrimary),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: TherapistPatientDetailScreen.kSub,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: TherapistPatientDetailScreen.kDark)),
        ]),
      ]),
    );
  }
}

class _AssignedExercisesCard extends StatelessWidget {
  final List<Map<String, dynamic>> assigned;
  final VoidCallback onAdd;
  const _AssignedExercisesCard(
      {required this.assigned, required this.onAdd});

  String _safe(dynamic v) => v == null ? '' : v.toString();

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Text('Assigned Exercises',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: TherapistPatientDetailScreen.kDark)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: TherapistPatientDetailScreen.kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onAdd,
            icon:  const Icon(Icons.add),
            label: const Text('Add Exercise',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 14),
        if (assigned.isEmpty)
          const Text('No exercises assigned yet.',
              style: TextStyle(
                  color: TherapistPatientDetailScreen.kSub,
                  fontWeight: FontWeight.w700))
        else
          ...assigned.map((row) {
            final title          = row['exercises']?['title'] ?? 'Exercise';
            final reps           = _safe(row['reps']);
            final totalDays      = _safe(row['total_days']);
            final sessionsPerDay = _safe(row['sessions_per_day']);
            final start          = _safe(row['start_date']);
            final end            = _safe(row['end_date']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExercisePlanTile(
                title:          title,
                reps:           reps,
                totalDays:      totalDays,
                sessionsPerDay: sessionsPerDay,
                startDate:      start,
                endDate:        end,
              ),
            );
          }),
      ]),
    );
  }
}

class _ExercisePlanTile extends StatelessWidget {
  final String title, reps, totalDays, sessionsPerDay, startDate, endDate;
  const _ExercisePlanTile({
    required this.title,
    required this.reps,
    required this.totalDays,
    required this.sessionsPerDay,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TherapistPatientDetailScreen.kBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withOpacity(0.08)),
      ),
      child: Row(children: [
        const Icon(Icons.fitness_center,
            color: TherapistPatientDetailScreen.kPrimary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: TherapistPatientDetailScreen.kDark)),
                const SizedBox(height: 4),
                Text(
                    '$reps reps • $sessionsPerDay sessions/day • $totalDays days',
                    style: const TextStyle(
                        color: TherapistPatientDetailScreen.kSub,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
                const SizedBox(height: 4),
                Text('From $startDate → $endDate',
                    style: const TextStyle(
                        color: TherapistPatientDetailScreen.kSub,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ]),
        ),
        const Icon(Icons.chevron_right),
      ]),
    );
  }
}

class _RecentSessionsCard extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  const _RecentSessionsCard({required this.sessions});

  String _fmt(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Recent Sessions',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: TherapistPatientDetailScreen.kDark)),
        const SizedBox(height: 12),
        if (sessions.isEmpty)
          const Text('No sessions recorded yet.',
              style: TextStyle(
                  color: TherapistPatientDetailScreen.kSub,
                  fontWeight: FontWeight.w700))
        else
          ...sessions.map((s) {
            final title = s['exercise_title'] ?? 'Exercise';
            final reps  = s['reps_done'] ?? 0;
            final secs  = s['duration_seconds'] ?? 0;
            final mins  = (secs ~/ 60);
            final date  = _fmt(s['created_at']?.toString());
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TherapistPatientDetailScreen.kBg,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.black12.withOpacity(0.08)),
                ),
                child: Row(children: [
                  const Icon(Icons.bar_chart_rounded,
                      color: TherapistPatientDetailScreen.kPrimary,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color:
                                      TherapistPatientDetailScreen.kDark)),
                          const SizedBox(height: 2),
                          Text('$reps reps  •  ${mins}m  •  $date',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: TherapistPatientDetailScreen.kSub,
                                  fontWeight: FontWeight.w700)),
                        ]),
                  ),
                ]),
              ),
            );
          }),
      ]),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final List<Map<String, dynamic>> feedbackList;
  final TextEditingController       controller;
  final VoidCallback                onSend;
  const _FeedbackCard({
    required this.feedbackList,
    required this.controller,
    required this.onSend,
  });

  String _fmt(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Send Feedback',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: TherapistPatientDetailScreen.kDark)),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Write a message to your patient...',
            filled: true,
            fillColor: TherapistPatientDetailScreen.kBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: TherapistPatientDetailScreen.kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onSend,
            icon:  const Icon(Icons.send, size: 18),
            label: const Text('Send',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
        if (feedbackList.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Previous messages',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: TherapistPatientDetailScreen.kSub,
                  fontSize: 13)),
          const SizedBox(height: 8),
          ...feedbackList.take(5).map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TherapistPatientDetailScreen.kBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 16,
                            color: TherapistPatientDetailScreen.kPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f['message'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color:
                                            TherapistPatientDetailScreen.kDark,
                                        fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(_fmt(f['created_at']?.toString()),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color:
                                            TherapistPatientDetailScreen.kSub)),
                              ]),
                        ),
                      ]),
                ),
              )),
        ],
      ]),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String? phone;
  final String? altPhone;
  final String? address;
  const _ContactCard(
      {required this.phone, required this.altPhone, required this.address});

  String _val(String? v) =>
      (v == null || v.trim().isEmpty) ? '-' : v;

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Emergency Contact',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: TherapistPatientDetailScreen.kDark)),
        const SizedBox(height: 12),
        _ContactRow(label: 'Patient Phone', value: _val(phone)),
        const SizedBox(height: 10),
        _ContactRow(label: 'Family Phone',  value: _val(altPhone)),
        const SizedBox(height: 10),
        _ContactRow(label: 'Address',       value: _val(address)),
      ]),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String label;
  final String value;
  const _ContactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(label,
            style: const TextStyle(
                color: TherapistPatientDetailScreen.kSub,
                fontWeight: FontWeight.w700)),
      ),
      Text(value,
          style: const TextStyle(
              color: TherapistPatientDetailScreen.kDark,
              fontWeight: FontWeight.w900)),
    ]);
  }
}

class _ModernCard extends StatelessWidget {
  final Widget child;
  const _ModernCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }
}

// ── Add Exercise Dialog ───────────────────────────────────────────────────────

class _AddExerciseDialog extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;
  final void Function(
          String exerciseId, int reps, int totalDays, int sessionsPerDay)
      onAssign;

  const _AddExerciseDialog(
      {required this.exercises, required this.onAssign});

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  String? selectedExerciseId;

  final TextEditingController repsCtrl     = TextEditingController(text: '10');
  final TextEditingController daysCtrl     = TextEditingController(text: '7');
  final TextEditingController sessionsCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    repsCtrl.dispose();
    daysCtrl.dispose();
    sessionsCtrl.dispose();
    super.dispose();
  }

  int _toInt(TextEditingController c, int fallback) {
    final v = int.tryParse(c.text.trim());
    if (v == null || v <= 0) return fallback;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exercises.isNotEmpty && selectedExerciseId == null) {
      selectedExerciseId = widget.exercises.first['id']?.toString();
    }

    return AlertDialog(
      title: const Text('Assign Exercise',
          style: TextStyle(fontWeight: FontWeight.w900)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: selectedExerciseId,
            decoration: const InputDecoration(labelText: 'Exercise'),
            items: widget.exercises.map<DropdownMenuItem<String>>((e) {
              final id    = e['id']?.toString() ?? '';
              final title = e['title']?.toString() ?? 'Exercise';
              return DropdownMenuItem<String>(
                  value: id, child: Text(title));
            }).toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() => selectedExerciseId = val);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: daysCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Total Days', hintText: 'Example: 14'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: sessionsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Sessions Per Day', hintText: 'Example: 2'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: repsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Reps Per Session', hintText: 'Example: 10'),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: TherapistPatientDetailScreen.kPrimary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (selectedExerciseId == null) return;
            widget.onAssign(
              selectedExerciseId!,
              _toInt(repsCtrl, 10),
              _toInt(daysCtrl, 7),
              _toInt(sessionsCtrl, 1),
            );
          },
          child: const Text('Assign',
              style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}