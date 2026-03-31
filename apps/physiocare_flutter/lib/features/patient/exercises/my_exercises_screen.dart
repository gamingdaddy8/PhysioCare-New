import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routes/app_routes.dart';

class MyExercisesScreen extends StatefulWidget {
  const MyExercisesScreen({super.key});

  @override
  State<MyExercisesScreen> createState() => _MyExercisesScreenState();
}

class _MyExercisesScreenState extends State<MyExercisesScreen> {
  static const Color kPrimary  = Color(0xFF1FC7B6);
  static const Color kBg       = Color(0xFFF8FAFC);
  static const Color kTextDark = Color(0xFF0F172A);
  static const Color kSub      = Color(0xFF64748B);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  List<Map<String, dynamic>> _allExercises = [];
  List<Map<String, dynamic>> _filtered = [];
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Auto-complete expired exercises
      await _supabase
          .from('assigned_exercises')
          .update({'status': 'completed'})
          .eq('status', 'active')
          .lt('end_date', DateTime.now().toIso8601String().substring(0, 10));

      final rows = await _supabase
          .from('assigned_exercises')
          .select('''
            id,
            reps,
            sets,
            sessions_per_day,
            total_days,
            start_date,
            end_date,
            status,
            created_at,
            exercises ( id, title, description )
          ''')
          .eq('patient_id', user.id)
          .order('created_at', ascending: false);

      _allExercises = List<Map<String, dynamic>>.from(rows);
      _applyFilter();
    } catch (e) {
      debugPrint('MyExercisesScreen load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    List<Map<String, dynamic>> list = List.from(_allExercises);

    if (_selectedFilter == 'Active') {
      list = list.where((e) => e['status'] == 'active').toList();
    } else if (_selectedFilter == 'Completed') {
      list = list.where((e) => e['status'] == 'completed').toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) {
        final title = (e['exercises']?['title'] ?? '').toString().toLowerCase();
        return title.contains(q);
      }).toList();
    }

    setState(() => _filtered = list);
  }

  void _onSearch(String value) {
    _searchQuery = value;
    _applyFilter();
  }

  void _onFilterTap(String filter) {
    _selectedFilter = filter;
    _applyFilter();
  }

  void _startExercise(BuildContext context, Map<String, dynamic> ex) {
    Navigator.pushNamed(
      context,
      AppRoutes.exerciseSession,
      arguments: {
        'assigned_exercise_id': ex['id']?.toString() ?? '',
        'exercise_id': ex['exercises']?['id']?.toString() ?? '',
        'title': ex['exercises']?['title'] ?? 'Exercise',
        'reps': ex['reps'] ?? 10,
      },
    );
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
        title: const Text(
          'My Exercises',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadExercises,
            icon: const Icon(Icons.refresh, color: kTextDark),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadExercises,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_allExercises.length} exercise${_allExercises.length == 1 ? '' : 's'} assigned',
                          style: const TextStyle(color: kSub),
                        ),
                        const SizedBox(height: 14),

                        TextField(
                          onChanged: _onSearch,
                          decoration: InputDecoration(
                            hintText: 'Search exercises...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Wrap(
                          spacing: 10,
                          children: ['All', 'Active', 'Completed']
                              .map((f) => GestureDetector(
                                    onTap: () => _onFilterTap(f),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _selectedFilter == f
                                            ? kPrimary
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _selectedFilter == f
                                              ? kPrimary
                                              : Colors.black12,
                                        ),
                                      ),
                                      child: Text(
                                        f,
                                        style: TextStyle(
                                          color: _selectedFilter == f
                                              ? Colors.white
                                              : kSub,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 18),

                        if (_filtered.isEmpty)
                          _EmptyCard(hasExercises: _allExercises.isNotEmpty)
                        else if (isWide)
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: _filtered
                                .map((ex) => SizedBox(
                                      width: 360,
                                      child: _ExerciseCard(
                                        exercise: ex,
                                        onStart: () =>
                                            _startExercise(context, ex),
                                      ),
                                    ))
                                .toList(),
                          )
                        else
                          Column(
                            children: _filtered
                                .map((ex) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 14),
                                      child: _ExerciseCard(
                                        exercise: ex,
                                        onStart: () =>
                                            _startExercise(context, ex),
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

class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final VoidCallback onStart;

  const _ExerciseCard({required this.exercise, required this.onStart});

  static const Color kPrimary  = Color(0xFF1FC7B6);
  static const Color kTextDark = Color(0xFF0F172A);
  static const Color kSub      = Color(0xFF64748B);

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':    return const Color(0xFF1FC7B6);
      case 'completed': return const Color(0xFF22C55E);
      case 'paused':    return const Color(0xFFF59E0B);
      default:          return kSub;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'active':    return 'Active';
      case 'completed': return 'Completed';
      case 'paused':    return 'Paused';
      default:          return status ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title      = exercise['exercises']?['title'] ?? 'Exercise';
    final desc       = exercise['exercises']?['description'] ?? '';
    final reps       = exercise['reps'] as int? ?? 0;
    final sessions   = exercise['sessions_per_day'] as int? ?? 1;
    final days       = exercise['total_days'] as int? ?? 0;
    final status     = exercise['status']?.toString();
    final start      = exercise['start_date']?.toString() ?? '';
    final end        = exercise['end_date']?.toString() ?? '';
    final isCompleted = status == 'completed';

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
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.fitness_center, color: kPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: kTextDark),
                    ),
                    if (desc.toString().isNotEmpty)
                      Text(
                        desc.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: kSub),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _statusColor(status)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _InfoChip(icon: Icons.repeat, label: '$reps reps'),
              _InfoChip(
                  icon: Icons.schedule,
                  label: '$sessions session${sessions == 1 ? '' : 's'}/day'),
              _InfoChip(icon: Icons.calendar_today, label: '$days days'),
            ],
          ),

          if (start.isNotEmpty && end.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '$start → $end',
              style: const TextStyle(fontSize: 12, color: kSub),
            ),
          ],

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCompleted ? kSub : kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: isCompleted ? null : onStart,
              icon: const Icon(Icons.play_arrow, size: 20),
              label: Text(
                isCompleted ? 'Completed' : 'Start Exercise',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final bool hasExercises;

  const _EmptyCard({required this.hasExercises});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Icon(
            hasExercises ? Icons.search_off : Icons.fitness_center_outlined,
            size: 40,
            color: const Color(0xFF64748B),
          ),
          const SizedBox(height: 10),
          Text(
            hasExercises ? 'No results found' : 'No exercises found',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            hasExercises
                ? 'Try a different search or filter.'
                : "Your physiotherapist hasn't assigned any exercises yet.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}