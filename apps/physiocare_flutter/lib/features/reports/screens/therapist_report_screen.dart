import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';
import '../models/report_model.dart';
import '../models/report_period.dart';
import '../services/report_service.dart';
import '../services/report_generator.dart';
import '../services/ai_summary_service.dart';
// TODO: uncomment and add your key:
// import 'package:physiocare_flutter/config/env.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1FC7B6);
const _kDark = Color(0xFF0F172A);
const _kSub = Color(0xFF64748B);
const _kBg = Color(0xFFF8FAFC);

class TherapistReportScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const TherapistReportScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<TherapistReportScreen> createState() => _TherapistReportScreenState();
}

class _TherapistReportScreenState extends State<TherapistReportScreen> {
  final _reportService = ReportService();
  // TODO: replace '' with Env.geminiApiKey once you have the key
  final _aiService = AiSummaryService(apiKey: '');

  ReportPeriod _period = ReportPeriod.week;
  ReportModel? _report;
  bool _loadingReport = true;
  bool _loadingAi = false;
  bool _sendingFeedback = false;
  bool _downloadingPdf = false;
  String? _error;

  final _notesCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────

  Future<void> _loadReport() async {
    setState(() {
      _loadingReport = true;
      _error = null;
      _report = null;
    });

    try {
      final report = await _reportService.buildReport(
        patientId: widget.patientId,
        period: _period,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loadingReport = false;
      });
      _generateAiSummary(report);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load report: $e';
        _loadingReport = false;
      });
    }
  }

  Future<void> _generateAiSummary(ReportModel base) async {
    if (base.totalSessions == 0) return;
    setState(() => _loadingAi = true);
    try {
      final summary = await _aiService.generateSummary(base);
      if (!mounted) return;
      setState(() {
        _report = _report?.copyWith(aiSummary: summary);
        _loadingAi = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAi = false);
    }
  }

  // ── Download PDF ──────────────────────────────────────────────

  Future<void> _downloadPdf() async {
    if (_report == null) return;
    setState(() => _downloadingPdf = true);
    try {
      // Attach clinical notes before generating
      final reportWithNotes = _report!.copyWith(
        therapistNotes: _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
      );
      // Save to Supabase reports table
      await _reportService.saveReport(reportWithNotes);
      // Generate PDF bytes
      final bytes = await ReportGenerator.generate(reportWithNotes);
      // Open share sheet (mobile) or download (web)
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'physiocare_${widget.patientName.replaceAll(' ', '_')}_report.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  // ── Send feedback ─────────────────────────────────────────────

  Future<void> _sendFeedback() async {
    final text = _feedbackCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sendingFeedback = true);
    try {
      final therapistId = Supabase.instance.client.auth.currentUser?.id;
      if (therapistId == null) return;

      await Supabase.instance.client.from('therapist_feedback').insert({
        'patient_id': widget.patientId,
        'therapist_id': therapistId,
        'message': text,
        'created_at': DateTime.now().toIso8601String(),
      });

      _feedbackCtrl.clear();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback sent to patient ✅'),
          backgroundColor: _kPrimary,
        ),
      );
      await _loadReport();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send feedback: $e')));
    } finally {
      if (mounted) setState(() => _sendingFeedback = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isWide = w >= 900;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.patientName,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: _kDark,
                fontSize: 16,
              ),
            ),
            const Text(
              'Progress Report',
              style: TextStyle(fontSize: 12, color: _kSub),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: _kDark),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadReport,
            icon: const Icon(Icons.refresh, color: _kDark),
          ),
          if (_report != null && _report!.totalSessions > 0)
            _downloadingPdf
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kPrimary,
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Download PDF',
                    onPressed: _downloadPdf,
                    icon: const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: _kPrimary,
                    ),
                  ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _PeriodSelector(
            selected: _period,
            onChanged: (p) {
              setState(() => _period = p);
              _loadReport();
            },
          ),
          Expanded(
            child: _loadingReport
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorView(message: _error!, onRetry: _loadReport)
                : _report == null
                ? const SizedBox()
                : isWide
                ? _WideBody(
                    report: _report!,
                    loadingAi: _loadingAi,
                    notesCtrl: _notesCtrl,
                    feedbackCtrl: _feedbackCtrl,
                    sendingFeedback: _sendingFeedback,
                    onSendFeedback: _sendFeedback,
                  )
                : _NarrowBody(
                    report: _report!,
                    loadingAi: _loadingAi,
                    notesCtrl: _notesCtrl,
                    feedbackCtrl: _feedbackCtrl,
                    sendingFeedback: _sendingFeedback,
                    onSendFeedback: _sendFeedback,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Period selector ───────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onChanged;
  const _PeriodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: ReportPeriod.values.map((p) {
          final active = p == selected;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(
                  p.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: active ? Colors.white : _kSub,
                  ),
                ),
                selected: active,
                onSelected: (_) => onChanged(p),
                selectedColor: _kPrimary,
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide.none,
                showCheckmark: false,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Wide layout (≥900px) ──────────────────────────────────────────────────────

class _WideBody extends StatelessWidget {
  final ReportModel report;
  final bool loadingAi;
  final bool sendingFeedback;
  final TextEditingController notesCtrl;
  final TextEditingController feedbackCtrl;
  final VoidCallback onSendFeedback;

  const _WideBody({
    required this.report,
    required this.loadingAi,
    required this.sendingFeedback,
    required this.notesCtrl,
    required this.feedbackCtrl,
    required this.onSendFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _dataWidgets(report, loadingAi),
              ),
            ),
            SizedBox(
              width: 340,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 16, 16, 32),
                children: _sideWidgets(
                  report: report,
                  notesCtrl: notesCtrl,
                  feedbackCtrl: feedbackCtrl,
                  sendingFeedback: sendingFeedback,
                  onSendFeedback: onSendFeedback,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Narrow layout (<900px) ────────────────────────────────────────────────────

class _NarrowBody extends StatelessWidget {
  final ReportModel report;
  final bool loadingAi;
  final bool sendingFeedback;
  final TextEditingController notesCtrl;
  final TextEditingController feedbackCtrl;
  final VoidCallback onSendFeedback;

  const _NarrowBody({
    required this.report,
    required this.loadingAi,
    required this.sendingFeedback,
    required this.notesCtrl,
    required this.feedbackCtrl,
    required this.onSendFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ..._dataWidgets(report, loadingAi),
            const SizedBox(height: 8),
            ..._sideWidgets(
              report: report,
              notesCtrl: notesCtrl,
              feedbackCtrl: feedbackCtrl,
              sendingFeedback: sendingFeedback,
              onSendFeedback: onSendFeedback,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Shared section builders ───────────────────────────────────────────────────

List<Widget> _dataWidgets(ReportModel report, bool loadingAi) {
  if (report.totalSessions == 0) {
    return [
      const SizedBox(height: 60),
      const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 56, color: _kSub),
            SizedBox(height: 14),
            Text(
              'No sessions found for this period.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _kSub,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    ];
  }
  return [
    _StatsBanner(report: report),
    const SizedBox(height: 16),
    _ExerciseBreakdown(breakdown: report.exerciseBreakdown),
    const SizedBox(height: 16),
    _BarChart(sessions: report.sessions),
    const SizedBox(height: 16),
    _SessionTable(sessions: report.sessions),
    const SizedBox(height: 16),
    _AiSummaryCard(summary: report.aiSummary, loading: loadingAi),
  ];
}

List<Widget> _sideWidgets({
  required ReportModel report,
  required TextEditingController notesCtrl,
  required TextEditingController feedbackCtrl,
  required bool sendingFeedback,
  required VoidCallback onSendFeedback,
}) {
  return [
    _ClinicalNotesCard(notesCtrl: notesCtrl),
    const SizedBox(height: 16),
    _SendFeedbackCard(
      feedbackCtrl: feedbackCtrl,
      feedbackList: report.therapistFeedback,
      sending: sendingFeedback,
      onSend: onSendFeedback,
    ),
  ];
}

// ── Stats banner ──────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  final ReportModel report;
  const _StatsBanner({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF1FC7B6), Color(0xFF21C6D6)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${report.patientName} — ${report.period.label}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (report.condition.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              report.condition,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip(
                label: 'Sessions',
                value: report.totalSessions.toString(),
              ),
              _StatChip(
                label: 'Total Reps',
                value: report.totalReps.toString(),
              ),
              _StatChip(
                label: 'Exercise Time',
                value: '${report.totalMinutes} min',
              ),
              _StatChip(
                label: 'Avg Reps',
                value: report.avgReps.toStringAsFixed(1),
              ),
              _StatChip(
                label: 'Avg Accuracy',
                value: '${report.avgAccuracy.toStringAsFixed(1)}%',
              ),
              _StatChip(
                label: 'Best Session',
                value: '${report.bestReps} reps',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                'Trend: ${report.progressTrend}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Exercise breakdown ────────────────────────────────────────────────────────

class _ExerciseBreakdown extends StatelessWidget {
  final Map<String, int> breakdown;
  const _ExerciseBreakdown({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) return const SizedBox();
    final total = breakdown.values.fold(0, (a, b) => a + b);

    return _Card(
      title: 'Exercise Breakdown',
      child: Column(
        children: breakdown.entries.map((entry) {
          final pct = total == 0 ? 0.0 : entry.value / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _kDark,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.value} reps  (${(pct * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 12, color: _kSub),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<SessionRow> sessions;
  const _BarChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final recent = sessions.reversed.take(12).toList();
    if (recent.isEmpty) return const SizedBox();
    final maxReps = recent
        .map((s) => s.repsDone)
        .reduce((a, b) => a > b ? a : b);

    return _Card(
      title: 'Reps Per Session (last ${recent.length})',
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: recent.map((s) {
            final pct = maxReps == 0 ? 0.0 : s.repsDone / maxReps;
            final abbr = s.exerciseTitle.length >= 2
                ? s.exerciseTitle.substring(0, 2).toUpperCase()
                : s.exerciseTitle.toUpperCase();
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${s.repsDone}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _kDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 100 * pct + 4,
                      decoration: BoxDecoration(
                        color: _kPrimary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      abbr,
                      style: const TextStyle(fontSize: 9, color: _kSub),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Session table ─────────────────────────────────────────────────────────────

class _SessionTable extends StatelessWidget {
  final List<SessionRow> sessions;
  const _SessionTable({required this.sessions});

  Color _accColor(double acc) {
    if (acc >= 80) return const Color(0xFF22C55E);
    if (acc >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Session History',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                ),
              ),
              children:
                  ['Date', 'Time', 'Exercise', 'Reps', 'Duration', 'Accuracy']
                      .map(
                        (h) => Padding(
                          padding: const EdgeInsets.fromLTRB(0, 4, 20, 8),
                          child: Text(
                            h,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: _kSub,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
            ...sessions.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final bg = i.isEven ? Colors.white : const Color(0xFFF8FAFC);
              final ac = _accColor(s.accuracy);
              return TableRow(
                decoration: BoxDecoration(color: bg),
                children: [
                  _TCell(_fmtDate(s.createdAt.toLocal())),
                  _TCell(_fmtTime(s.createdAt.toLocal())),
                  _TCell(s.exerciseTitle),
                  _TCell(s.repsDone.toString()),
                  _TCell('${(s.durationSeconds / 60).toStringAsFixed(1)} min'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 20, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ac.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${s.accuracy.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: ac,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TCell extends StatelessWidget {
  final String text;
  const _TCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 20, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: _kDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── AI summary card ───────────────────────────────────────────────────────────

class _AiSummaryCard extends StatelessWidget {
  final String summary;
  final bool loading;
  const _AiSummaryCard({required this.summary, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: _kPrimary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'AI Clinical Assessment',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _kDark,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kPrimary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading && summary.isEmpty)
            const Text(
              'Generating clinical summary…',
              style: TextStyle(color: _kSub, fontStyle: FontStyle.italic),
            )
          else
            Text(
              summary.isEmpty ? 'No summary available.' : summary,
              style: const TextStyle(color: _kDark, height: 1.55, fontSize: 14),
            ),
          const SizedBox(height: 10),
          Text(
            'AI-generated note. Not a substitute for professional clinical judgement.',
            style: TextStyle(
              fontSize: 11,
              color: _kSub.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clinical notes card (PDF-only, not sent to patient) ───────────────────────

class _ClinicalNotesCard extends StatelessWidget {
  final TextEditingController notesCtrl;
  const _ClinicalNotesCard({required this.notesCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note, color: Color(0xFFF59E0B), size: 18),
              SizedBox(width: 8),
              Text(
                'Clinical Notes (PDF only)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _kDark,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'These notes appear in the exported PDF but are not sent to the patient.',
            style: TextStyle(fontSize: 12, color: _kSub),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add clinical observations for this report…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFDE68A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFF59E0B),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Send feedback card ────────────────────────────────────────────────────────

class _SendFeedbackCard extends StatelessWidget {
  final TextEditingController feedbackCtrl;
  final List<FeedbackRow> feedbackList;
  final bool sending;
  final VoidCallback onSend;

  const _SendFeedbackCard({
    required this.feedbackCtrl,
    required this.feedbackList,
    required this.sending,
    required this.onSend,
  });

  String _fmtDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/'
        '${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Send Feedback to Patient',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: feedbackCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write a message for the patient…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kPrimary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(
                sending ? 'Sending…' : 'Send Feedback',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          if (feedbackList.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Previous messages',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _kSub,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ...feedbackList
                .take(5)
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 16,
                            color: _kPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.message,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _kDark,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _fmtDate(f.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _kSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

// ── Shared card wrapper ───────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kSub),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
