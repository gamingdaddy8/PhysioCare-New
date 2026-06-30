import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/audio_feedback_service.dart';
import '../../../data/services/pain_alert_service.dart';
import '../pose_detector/camera_pose_view.dart';
import '../pose_detector/exercise_type.dart';
import '../pose_detector/web_pose_view_stub.dart'
    if (dart.library.js_interop) '../pose_detector/web_pose_view.dart';
import '../pose_detector/exercise_reference_player.dart';

class ExerciseSessionScreen extends StatefulWidget {
  const ExerciseSessionScreen({super.key});

  @override
  State<ExerciseSessionScreen> createState() => _ExerciseSessionScreenState();
}

class _ExerciseSessionScreenState extends State<ExerciseSessionScreen> {
  static const Color kPrimary  = Color(0xFF1FC7B6);
  static const Color kBg       = Color(0xFFF8FAFC);
  static const Color kTextDark = Color(0xFF0F172A);
  static const Color kSub      = Color(0xFF64748B);

  final SupabaseClient _supabase = Supabase.instance.client;

  // Route arguments — populated in didChangeDependencies
  String _assignedExerciseId = '';
  String _exerciseId         = '';
  String _exerciseTitle      = 'Exercise';
  int    _targetReps         = 10;

  // Session state
  bool _audioEnabled  = true;
  bool _sessionSaving = false;
  int    _currentRep    = 0;
  double _liveAccuracy  = 0.0;
  final Stopwatch _stopwatch = Stopwatch();

  ExerciseType _exercise = ExerciseType.bicepCurl;

  bool _argumentsLoaded = false;

  // Pain alert state
  bool _alertSent     = false;
  bool _sessionPaused = false;
  String _therapistId   = '';
  String _therapistName = 'your therapist';
  String _patientName   = 'Patient';
  bool _endedByPainAlert = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentsLoaded) return;
    _argumentsLoaded = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _assignedExerciseId = args['assigned_exercise_id']?.toString() ?? '';
      _exerciseId         = args['exercise_id']?.toString() ?? '';
      _exerciseTitle      = args['title']?.toString() ?? 'Exercise';
      _targetReps         = (args['reps'] as int?) ?? 10;

      // Map title to ExerciseType for the pose engine
      _exercise = _titleToExerciseType(_exerciseTitle);
    }

    _stopwatch.start();
    AudioFeedbackService.instance.init();
    _loadSessionContext();
  }

  /// Load therapist and patient info for pain alert context.
  Future<void> _loadSessionContext() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Patient profile
      final profile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null) {
        _patientName = profile['full_name']?.toString() ?? 'Patient';
      }

      // Therapist from assigned exercise
      if (_assignedExerciseId.isNotEmpty) {
        final assigned = await _supabase
            .from('assigned_exercises')
            .select('therapist_id')
            .eq('id', _assignedExerciseId)
            .maybeSingle();
        final tId = assigned?['therapist_id']?.toString() ?? '';
        if (tId.isNotEmpty) {
          _therapistId = tId;
          final tp = await _supabase
              .from('profiles')
              .select('full_name')
              .eq('id', tId)
              .maybeSingle();
          if (tp != null) {
            _therapistName = tp['full_name']?.toString() ?? 'your therapist';
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load session context: $e');
    }
  }

  @override
  void dispose() {
    _stopwatch.stop();
    AudioFeedbackService.instance.stop();
    super.dispose();
  }

  ExerciseType _titleToExerciseType(String title) {
    final t = title.toLowerCase();
    if (t.contains('bicep') || t.contains('curl')) return ExerciseType.bicepCurl;
    if (t.contains('side') || t.contains('raise')) return ExerciseType.sideRaise;
    if (t.contains('squat'))                        return ExerciseType.squats;
    if (t.contains('abduction'))                    return ExerciseType.standingHipAbduction;
    if (t.contains('knee'))                         return ExerciseType.seatedKneeExtension;
    return ExerciseType.bicepCurl;
  }

  String _exerciseTypeTitle(ExerciseType ex) {
    switch (ex) {
      case ExerciseType.bicepCurl:          return 'Bicep Curl';
      case ExerciseType.sideRaise:          return 'Side Raise';
      case ExerciseType.squats:             return 'Squats';
      case ExerciseType.standingHipAbduction: return 'Standing Hip Abduction';
      case ExerciseType.seatedKneeExtension:  return 'Seated Knee Extension';
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

      // Use cached therapist ID if available, else fetch
      String? therapistId = _therapistId.isNotEmpty ? _therapistId : null;
      if (therapistId == null && _assignedExerciseId.isNotEmpty) {
        final assigned = await _supabase
            .from('assigned_exercises')
            .select('therapist_id')
            .eq('id', _assignedExerciseId)
            .maybeSingle();
        therapistId = assigned?['therapist_id']?.toString();
      }

      // Save session report
      await _supabase.from('session_reports').insert({
        'patient_id':           user.id,
        'therapist_id':         therapistId,
        'exercise_id':          _exerciseId.isNotEmpty ? _exerciseId : null,
        'exercise_title':       _exerciseTitle,
        'reps_done':            _currentRep,
        'duration_seconds':     durationSeconds,
        'accuracy':             _liveAccuracy,
        'notes':                null,
        'ended_by_pain_alert':  _endedByPainAlert,
        'created_at':           DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      // Show completion dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SessionCompleteDialog(
          exerciseTitle:     _exerciseTitle,
          reps:              _currentRep,
          durationSeconds:   durationSeconds,
          endedByPainAlert:  _endedByPainAlert,
          onDone: () {
            Navigator.of(context).pop(); // close dialog
            Navigator.of(context).pop(); // go back to exercises
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save session: $e')),
      );
    } finally {
      if (mounted) setState(() => _sessionSaving = false);
    }
  }

  Future<void> _stopSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stop Session?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
            'You have completed $_currentRep of $_targetReps reps.\nSave progress and exit?'),
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
            child: const Text('Stop & Save',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _finishSession();
    }
  }

  // ── Pain alert methods ──────────────────────────────────────────

  void _showPainAlertDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _PainAlertDialog(
        onSend: (painLevel, message) {
          Navigator.of(ctx).pop();
          _submitPainAlert(painLevel, message);
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Future<void> _submitPainAlert(int painLevel, String? message) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _alertSent = true;
      _sessionPaused = true;
      _endedByPainAlert = true;
    });
    _stopwatch.stop();

    final alertId = await PainAlertService().submitPainAlert(
      patientId:             user.id,
      therapistId:           _therapistId,
      exerciseTitle:         _exerciseTitle,
      painLevel:             painLevel,
      patientName:           _patientName,
      message:               message,
      sessionDurationSeconds: _stopwatch.elapsed.inSeconds,
    );

    if (!mounted) return;

    // Show feedback even if queued for retry
    if (alertId == null && PainAlertService().hasPendingAlert) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert is being sent — please stay safe.'),
          backgroundColor: Color(0xFFE53935),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _resumeSession() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resume Session?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          'We recommend checking with your therapist before continuing.\n\n'
          'Are you sure you want to resume?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay Paused'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _sessionPaused = false);
              _stopwatch.start();
            },
            child: const Text('Resume',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _stopSession,
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              _exerciseTitle,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              _sessionPaused
                  ? '⏸ Session Paused'
                  : 'Rep $_currentRep of $_targetReps',
              style: TextStyle(
                fontSize: 12,
                color: _sessionPaused ? Colors.red : kSub,
                fontWeight: _sessionPaused ? FontWeight.w700 : FontWeight.normal,
              ),
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
              onPressed: () {
                final newVal = !_audioEnabled;
                setState(() => _audioEnabled = newVal);
                AudioFeedbackService.instance.enabled = newVal;
              },
              icon: Icon(_audioEnabled
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          // ── Alert banner ──
          if (_alertSent)
            _PainAlertBanner(
              therapistName: _therapistName,
              onEndSession: _finishSession,
              onResume: _sessionPaused ? _resumeSession : null,
            ),

          // ── Main content ──
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: isWide ? _wideLayout() : _narrowLayout(),
                ),
              ),
            ),
          ),
        ],
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
              bg: const Color(0xFFDC2626),
              icon: Icons.warning_rounded,
              tooltip: 'Pain Alert',
              onTap: _showPainAlertDialog,
            ),
            const SizedBox(width: 16),
            _CircleButton(
              bg: Colors.white,
              icon: Icons.check_circle_outline,
              iconColor: kPrimary,
              border: true,
              onTap: _finishSession,
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

  Widget _narrowLayout() {
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: _cameraPanel(),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _referencePanel(),
        ),
      ],
    );
  }

  Widget _cameraPanel() {
    return _PanelCard(
      label: 'Your Camera',
      topRightWidget: Text(
        _exerciseTypeTitle(_exercise),
        style: const TextStyle(
          color: kTextDark,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      child: kIsWeb
          ? WebPoseView(
              initialExercise:    _exercise,
              onRepCompleted:     _onRepCompleted,
              onAccuracyUpdated:  _onAccuracyUpdated,
              targetReps:         _targetReps,
            )
          : CameraPoseView(
              showOverlayUI:     false,
              initialExercise:   _exercise,
              onRepCompleted:    _onRepCompleted,
              onAccuracyUpdated: _onAccuracyUpdated,
              targetReps:        _targetReps,
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
                    valueColor:
                        const AlwaysStoppedAnimation(kPrimary),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '$_currentRep',
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: kTextDark),
                    ),
                    Text(
                      'of $_targetReps',
                      style: const TextStyle(
                          fontSize: 13, color: kSub),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Accuracy chip
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Accuracy: ${_liveAccuracy.toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kPrimary,
                    fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),

            Text(
              _currentRep >= _targetReps
                  ? '🎉 Target reached!'
                  : '${_targetReps - _currentRep} reps remaining',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _currentRep >= _targetReps
                    ? kPrimary
                    : kTextDark,
              ),
            ),
            const SizedBox(height: 24),

            // ── Reference video player ────────────────────────
            SizedBox(
              height: 300,
              child: ExerciseReferencePlayer(
                exercise: _exercise,
              ),
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
  final bool endedByPainAlert;
  final VoidCallback onDone;

  const _SessionCompleteDialog({
    required this.exerciseTitle,
    required this.reps,
    required this.durationSeconds,
    this.endedByPainAlert = false,
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
    final iconColor = endedByPainAlert
        ? const Color(0xFFE53935)
        : const Color(0xFF1FC7B6);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              endedByPainAlert ? Icons.warning_rounded : Icons.check_circle,
              color: iconColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            endedByPainAlert ? 'Session Ended' : 'Session Complete! 🎉',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(exerciseTitle,
              style: const TextStyle(color: Color(0xFF64748B))),
          if (endedByPainAlert) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Session was interrupted due to a pain alert.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
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
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: onDone,
              child: const Text('Done',
                  style: TextStyle(fontWeight: FontWeight.w900)),
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
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared panel card widget
// ---------------------------------------------------------------------------

class _PanelCard extends StatelessWidget {
  final String  label;
  final Widget  child;
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
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
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
  final Color    bg;
  final IconData icon;
  final Color    iconColor;
  final bool     border;
  final String?  tooltip;
  final VoidCallback onTap;

  const _CircleButton({
    required this.bg,
    required this.icon,
    this.iconColor = Colors.white,
    this.border    = false,
    this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn = Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          height: 62,
          width:  62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: border ? Border.all(color: Colors.black12) : null,
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
      ),
    );

    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

// ---------------------------------------------------------------------------
// Pain Alert Confirmation Dialog
// ---------------------------------------------------------------------------

class _PainAlertDialog extends StatefulWidget {
  final void Function(int painLevel, String? message) onSend;
  final VoidCallback onCancel;

  const _PainAlertDialog({
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<_PainAlertDialog> createState() => _PainAlertDialogState();
}

class _PainAlertDialogState extends State<_PainAlertDialog> {
  int _painLevel = 7;
  final TextEditingController _messageCtrl = TextEditingController();
  Timer? _autoDismissTimer;
  int _secondsRemaining = 60;
  bool _userInteracted = false;

  @override
  void initState() {
    super.initState();
    _autoDismissTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_userInteracted) {
        // Reset timer on interaction
        _secondsRemaining = 60;
        _userInteracted = false;
        return;
      }
      _secondsRemaining--;
      if (_secondsRemaining <= 0) {
        timer.cancel();
        if (mounted) widget.onCancel();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _markInteracted() => _userInteracted = true;

  Color _painColor(int level) {
    if (level <= 3) return const Color(0xFF22C55E);
    if (level <= 5) return const Color(0xFFF59E0B);
    if (level <= 7) return const Color(0xFFF97316);
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top bar: title + cancel
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_rounded,
                        color: Color(0xFFE53935), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Pain Alert',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A))),
                  ),
                  TextButton(
                    onPressed: widget.onCancel,
                    child: Text('Cancel',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Pain level
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Pain Level',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A))),
              ),
              const SizedBox(height: 8),

              // Large number display
              Text(
                '$_painLevel',
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: _painColor(_painLevel),
                ),
              ),
              Text(
                'out of 10',
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),

              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _painColor(_painLevel),
                  thumbColor: _painColor(_painLevel),
                  inactiveTrackColor:
                      _painColor(_painLevel).withValues(alpha: 0.2),
                  overlayColor:
                      _painColor(_painLevel).withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: _painLevel.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '$_painLevel',
                  onChanged: (v) {
                    _markInteracted();
                    setState(() => _painLevel = v.round());
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mild', style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
                  Text('Severe', style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(height: 16),

              // Message field
              TextField(
                controller: _messageCtrl,
                maxLines: 2,
                onChanged: (_) => _markInteracted(),
                decoration: InputDecoration(
                  labelText: 'What happened? (optional)',
                  hintText: 'e.g. sharp knee pain, feeling dizzy',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Send Alert button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final msg = _messageCtrl.text.trim();
                    widget.onSend(_painLevel, msg.isEmpty ? null : msg);
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Send Alert',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),

              // Auto-dismiss indicator
              const SizedBox(height: 10),
              Text(
                'Auto-dismisses in ${_secondsRemaining}s',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pain Alert Banner — shown after alert is sent
// ---------------------------------------------------------------------------

class _PainAlertBanner extends StatelessWidget {
  final String therapistName;
  final VoidCallback onEndSession;
  final VoidCallback? onResume;

  const _PainAlertBanner({
    required this.therapistName,
    required this.onEndSession,
    this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('\uD83D\uDEA8 Alert sent. Help is on the way.',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your alert has been sent to $therapistName. '
              'You can close this session when you feel ready.',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFE53935),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: onEndSession,
                    child: const Text('End Session',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                if (onResume != null) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onResume,
                    child: const Text('Resume',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}