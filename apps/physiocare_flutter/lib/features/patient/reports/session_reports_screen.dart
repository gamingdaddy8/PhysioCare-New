import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionReportsScreen extends StatefulWidget {
  const SessionReportsScreen({super.key});

  @override
  State<SessionReportsScreen> createState() => _SessionReportsScreenState();
}

class _SessionReportsScreenState extends State<SessionReportsScreen> {
  static const Color kPrimary  = Color(0xFF1FC7B6);
  static const Color kBg       = Color(0xFFF8FAFC);
  static const Color kTextDark = Color(0xFF0F172A);
  static const Color kSub      = Color(0xFF64748B);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  List<Map<String, dynamic>> _sessions = [];

  // Computed stats
  int    _totalSessions    = 0;
  int    _totalMinutes     = 0;
  int    _weekSessions     = 0;
  double _weekAvgReps      = 0;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

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
          .eq('patient_id', user.id)
          .order('created_at', ascending: false);

      _sessions = List<Map<String, dynamic>>.from(rows);
      _computeStats();
    } catch (e) {
      debugPrint('SessionReportsScreen load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _computeStats() {
    _totalSessions = _sessions.length;

    int totalSecs = 0;
    for (final s in _sessions) {
      totalSecs += (s['duration_seconds'] as int? ?? 0);
    }
    _totalMinutes = totalSecs ~/ 60;

    // This week stats
    final now      = DateTime.now();
    final weekAgo  = now.subtract(const Duration(days: 7));
    final weekRows = _sessions.where((s) {
      try {
        final dt = DateTime.parse(s['created_at'].toString());
        return dt.isAfter(weekAgo);
      } catch (_) {
        return false;
      }
    }).toList();

    _weekSessions = weekRows.length;

    if (weekRows.isNotEmpty) {
      final totalReps = weekRows.fold<int>(
          0, (sum, s) => sum + (s['reps_done'] as int? ?? 0));
      _weekAvgReps = totalReps / weekRows.length;
    } else {
      _weekAvgReps = 0;
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _fmtDuration(int? secs) {
    if (secs == null || secs == 0) return '0 min';
    final m = secs ~/ 60;
    final s = secs % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m} min';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final w      = MediaQuery.of(context).size.width;
    final isWide = w >= 900;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session Reports',
                style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 2),
            Text('Track your recovery progress',
                style: TextStyle(fontSize: 12, color: kSub)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh, color: kTextDark),
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
                  onRefresh: _loadReports,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Stats banner ──────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [kPrimary, Color(0xFF21C6D6)],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "This Week's Sessions",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '$_weekSessions',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatItem(
                                      value: '$_totalSessions',
                                      label: 'All Sessions',
                                    ),
                                  ),
                                  Expanded(
                                    child: _StatItem(
                                      value: '$_totalMinutes min',
                                      label: 'Total Time',
                                    ),
                                  ),
                                  Expanded(
                                    child: _StatItem(
                                      value: _weekAvgReps == 0
                                          ? '—'
                                          : '${_weekAvgReps.toStringAsFixed(1)}',
                                      label: 'Avg Reps/Session',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        const Text(
                          'Session History',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: kTextDark),
                        ),
                        const SizedBox(height: 10),

                        // ── Session list ──────────────────────────────
                        if (_sessions.isEmpty)
                          _EmptyHistoryCard()
                        else if (isWide)
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: _sessions
                                .map((s) => SizedBox(
                                      width: 360,
                                      child: _SessionCard(
                                        session: s,
                                        fmtDate: _fmtDate,
                                        fmtDuration: _fmtDuration,
                                      ),
                                    ))
                                .toList(),
                          )
                        else
                          Column(
                            children: _sessions
                                .map((s) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 14),
                                      child: _SessionCard(
                                        session: s,
                                        fmtDate: _fmtDate,
                                        fmtDuration: _fmtDuration,
                                      ),
                                    ))
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

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withOpacity(0.9), fontSize: 12)),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String Function(String?) fmtDate;
  final String Function(int?) fmtDuration;

  const _SessionCard({
    required this.session,
    required this.fmtDate,
    required this.fmtDuration,
  });

  static const Color kPrimary  = Color(0xFF1FC7B6);
  static const Color kTextDark = Color(0xFF0F172A);
  static const Color kSub      = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final title    = session['exercise_title'] ?? 'Exercise';
    final reps     = session['reps_done'] ?? 0;
    final secs     = session['duration_seconds'] as int?;
    final feedback = session['notes']?.toString() ?? '';
    final date     = fmtDate(session['created_at']?.toString());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: kPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: kTextDark)),
                    Text(date,
                        style:
                            const TextStyle(fontSize: 12, color: kSub)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          Row(
            children: [
              _DetailChip(
                icon: Icons.repeat,
                label: '$reps reps completed',
              ),
              const SizedBox(width: 14),
              _DetailChip(
                icon: Icons.timer_outlined,
                label: fmtDuration(secs),
              ),
            ],
          ),

          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 16, color: kPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feedback,
                      style: const TextStyle(
                          fontSize: 13,
                          color: kTextDark,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
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
      child: const Column(
        children: [
          SizedBox(height: 6),
          Icon(Icons.history_toggle_off,
              size: 40, color: Color(0xFF64748B)),
          SizedBox(height: 10),
          Text(
            'No sessions yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A)),
          ),
          SizedBox(height: 6),
          Text(
            'Complete your first exercise to see your reports here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}