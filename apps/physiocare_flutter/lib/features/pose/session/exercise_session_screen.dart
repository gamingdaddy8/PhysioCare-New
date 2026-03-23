import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pose_detector/camera_pose_view.dart';
import '../pose_detector/exercise_type.dart';
import '../pose_detector/web_pose_view.dart';
import '../pose_detector/exercise_reference_player.dart';

class ExerciseSessionScreen extends StatefulWidget {
  const ExerciseSessionScreen({super.key});

  @override
  State<ExerciseSessionScreen> createState() => _ExerciseSessionScreenState();
}

class _ExerciseSessionScreenState extends State<ExerciseSessionScreen> {
  static const Color kPrimary = Color(0xFF1FC7B6);
  static const Color kBg = Color(0xFFF8FAFC);
  static const Color kTextDark = Color(0xFF0F172A);
  static const Color kSub = Color(0xFF64748B);

  final SupabaseClient _supabase = Supabase.instance.client;

  // Route arguments — populated in didChangeDependencies
  String _assignedExerciseId = '';
  String _exerciseId = '';
  String _exerciseTitle = 'Exercise';
  int _targetReps = 10;

  // Session state
  bool _audioEnabled = true;
  bool _sessionSaving = false;
  int _currentRep = 0;
  double _liveAccuracy = 0.0;
  final Stopwatch _stopwatch = Stopwatch();

  ExerciseType _exercise = ExerciseType.bicepCurl;

  bool _argumentsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentsLoaded) return;
    _argumentsLoaded = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _assignedExerciseId = args['assigned_exercise_id']?.toString() ?? '';
      _exerciseId = args['exercise_id']?.toString() ?? '';
      _exerciseTitle = args['title']?.toString() ?? 'Exercise';
      _targetReps = (args['reps'] as int?) ?? 10;

      // Map title to ExerciseType for the pose engine
      _exercise = _titleToExerciseType(_exerciseTitle);
    }

    _stopwatch.start();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  ExerciseType _titleToExerciseType(String title) {
    final t = title.toLowerCase();
    if (t.contains('bicep') || t.contains('curl'))
      return ExerciseType.bicepCurl;
    if (t.contains('side') || t.contains('raise'))
      return ExerciseType.sideRaise;
    if (t.contains('squat')) return ExerciseType.squats;
    return ExerciseType.bicepCurl;
  }

  String _exerciseTypeTitle(ExerciseType ex) {
    switch (ex) {
      case ExerciseType.bicepCurl:
        return 'Bicep Curl';
      case ExerciseType.sideRaise:
        return 'Side Raise';
      case ExerciseType.squats:
        return 'Squats';
    }
  }

  // Called by pose engine with live accuracy
  void _onAccuracyUpdated(double accuracy) {
    _liveAccuracy = accuracy;
  }

  // Called by pose engine when a rep is completed
  void _onRepCompleted(int repCount) {
    setState(() => _currentRep = repCount);

    // Auto-finish when target reps reached
    if (repCount >= _targetReps) {
      _finishSession();
    }
  }

  Future<void> _finishSession() async {
    if (_sessionSaving) return;
    setState(() => _sessionSaving = true);

    _stopwatch.stop();
    final durationSeconds = _stopwatch.elapsed.inSeconds;

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Fetch therapist_id from assigned_exercises for this record
      String? therapistId;
      if (_assignedExerciseId.isNotEmpty) {
        final assigned = await _supabase
            .from('assigned_exercises')
            .select('therapist_id')
            .eq('id', _assignedExerciseId)
            .maybeSingle();
        therapistId = assigned?['therapist_id']?.toString();
      }

      // Save session report
      await _supabase.from('session_reports').insert({
        'patient_id': user.id,
        'therapist_id': therapistId,
        'exercise_id': _exerciseId.isNotEmpty ? _exerciseId : null,
        'exercise_title': _exerciseTitle,
        'reps_done': _currentRep,
        'duration_seconds': durationSeconds,
        'accuracy': _liveAccuracy,
        'notes': null,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      // Show completion dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SessionCompleteDialog(
          exerciseTitle: _exerciseTitle,
          reps: _currentRep,
          durationSeconds: durationSeconds,
          onDone: () {
            Navigator.of(context).pop(); // close dialog
            Navigator.of(context).pop(); // go back to exercises
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save session: $e')));
    } finally {
      if (mounted) setState(() => _sessionSaving = false);
    }
  }

  Future<void> _stopSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Stop Session?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'You have completed $_currentRep of $_targetReps reps.\nSave progress and exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Stop & Save',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _finishSession();
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _stopSession,
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              _exerciseTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              'Rep $_currentRep of $_targetReps',
              style: const TextStyle(fontSize: 12, color: kSub),
            ),
          ],
        ),
        actions: [
          if (_sessionSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Audio',
              onPressed: () => setState(() => _audioEnabled = !_audioEnabled),
              icon: Icon(
                _audioEnabled
                    ? Icons.volume_up_outlined
                    : Icons.volume_off_outlined,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),

      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: isWide ? _wideLayout() : _mobileBlocked(),
          ),
        ),
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CircleButton(
              bg: Colors.red,
              icon: Icons.stop,
              onTap: _stopSession,
            ),
            const SizedBox(width: 16),
            _CircleButton(
              bg: Colors.white,
              icon: Icons.check_circle_outline,
              iconColor: kPrimary,
              border: true,
              onTap: _finishSession,
            ),
            const SizedBox(width: 16),
            _CircleButton(
              bg: Colors.white,
              icon: Icons.chat_bubble_outline,
              iconColor: kTextDark,
              border: true,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chat with therapist — coming soon'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideLayout() {
    return Row(
      children: [
        Expanded(child: _cameraPanel()),
        const SizedBox(width: 16),
        Expanded(child: _referencePanel()),
      ],
    );
  }

  Widget _mobileBlocked() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.desktop_windows, size: 44, color: kSub),
          SizedBox(height: 14),
          Text(
            'Web Mode Only',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: kTextDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This exercise session layout is designed for Web/Tablet.\n\nOpen PhysioCare on a wider screen to continue.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kSub),
          ),
        ],
      ),
    );
  }

  Widget _cameraPanel() {
    return _PanelCard(
      label: 'Your Camera',
      topRightWidget: DropdownButtonHideUnderline(
        child: DropdownButton<ExerciseType>(
          value: _exercise,
          dropdownColor: Colors.white,
          style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w700),
          items: const [
            DropdownMenuItem(
              value: ExerciseType.bicepCurl,
              child: Text('Bicep Curl'),
            ),
            DropdownMenuItem(
              value: ExerciseType.sideRaise,
              child: Text('Side Raise'),
            ),
            DropdownMenuItem(value: ExerciseType.squats, child: Text('Squats')),
          ],
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              _exercise = val;
              _currentRep = 0;
              _stopwatch
                ..reset()
                ..start();
            });
          },
        ),
      ),
      child: kIsWeb
          ? WebPoseView(
              initialExercise: _exercise,
              onRepCompleted: _onRepCompleted,
              onAccuracyUpdated: _onAccuracyUpdated,
            )
          : CameraPoseView(
              showOverlayUI: false,
              initialExercise: _exercise,
              onRepCompleted: _onRepCompleted,
              onAccuracyUpdated: _onAccuracyUpdated,
            ),
    );
  }

  Widget _referencePanel() {
    return _PanelCard(
      label: 'Reference & Progress',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // ── Progress ring ─────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 140,
                  width: 140,
                  child: CircularProgressIndicator(
                    value: _targetReps > 0
                        ? (_currentRep / _targetReps).clamp(0.0, 1.0)
                        : 0,
                    strokeWidth: 10,
                    backgroundColor: Colors.black12,
                    valueColor: const AlwaysStoppedAnimation(kPrimary),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '$_currentRep',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: kTextDark,
                      ),
                    ),
                    Text(
                      'of $_targetReps',
                      style: const TextStyle(fontSize: 13, color: kSub),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Accuracy chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Accuracy: ${_liveAccuracy.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: kPrimary,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Text(
              _currentRep >= _targetReps
                  ? '🎉 Target reached!'
                  : '${_targetReps - _currentRep} reps remaining',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _currentRep >= _targetReps ? kPrimary : kTextDark,
              ),
            ),
            const SizedBox(height: 24),

            // ── Reference video player ────────────────────────
            SizedBox(
              height: 300,
              child: ExerciseReferencePlayer(exercise: _exercise),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session complete dialog
// ---------------------------------------------------------------------------

class _SessionCompleteDialog extends StatelessWidget {
  final String exerciseTitle;
  final int reps;
  final int durationSeconds;
  final VoidCallback onDone;

  const _SessionCompleteDialog({
    required this.exerciseTitle,
    required this.reps,
    required this.durationSeconds,
    required this.onDone,
  });

  String get _duration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF1FC7B6).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFF1FC7B6),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Session Complete! 🎉',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(exerciseTitle, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatChip(label: 'Reps', value: '$reps'),
              _StatChip(label: 'Time', value: _duration),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FC7B6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: onDone,
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared panel card widget
// ---------------------------------------------------------------------------

class _PanelCard extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? topRightWidget;

  const _PanelCard({
    required this.label,
    required this.child,
    this.topRightWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (topRightWidget != null) topRightWidget!,
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Circle button widget
// ---------------------------------------------------------------------------

class _CircleButton extends StatelessWidget {
  final Color bg;
  final IconData icon;
  final Color iconColor;
  final bool border;
  final VoidCallback onTap;

  const _CircleButton({
    required this.bg,
    required this.icon,
    this.iconColor = Colors.white,
    this.border = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          height: 62,
          width: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: border ? Border.all(color: Colors.black12) : null,
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
      ),
    );
  }
}
