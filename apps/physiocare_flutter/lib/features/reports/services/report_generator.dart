import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/report_model.dart';
import '../models/report_period.dart';

class ReportGenerator {
  // ── Brand colours ─────────────────────────────────────────────
  static const _teal = PdfColor.fromInt(0xFF1FC7B6);
  static const _tealLight = PdfColor.fromInt(0xFF21C6D6);
  static const _dark = PdfColor.fromInt(0xFF0F172A);
  static const _sub = PdfColor.fromInt(0xFF64748B);
  static const _bg = PdfColor.fromInt(0xFFF8FAFC);
  static const _white = PdfColors.white;
  static const _amber = PdfColor.fromInt(0xFFF59E0B);
  static const _amberBg = PdfColor.fromInt(0xFFFFFBEB);
  static const _green = PdfColor.fromInt(0xFF22C55E);
  static const _red = PdfColor.fromInt(0xFFEF4444);

  /// Generate PDF bytes from a [ReportModel].
  /// Call [Printing.sharePdf] with the result to open the share sheet.
  static Future<Uint8List> generate(ReportModel report) async {
    final doc = pw.Document();

    // Use built-in PDF fonts — no asset files needed
    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );

    // ── Page 1: Header + Stats + Chart ───────────────────────────
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(report, ctx),
        footer: (ctx) => _buildFooter(report, ctx),
        build: (ctx) => [
          _buildTherapistCard(report),
          pw.SizedBox(height: 20),
          _buildStatsBanner(report),
          pw.SizedBox(height: 20),
          _buildExerciseBreakdown(report),
          pw.SizedBox(height: 20),
          _buildBarChart(report),
          pw.SizedBox(height: 20),
          _buildSessionTable(report),
          pw.SizedBox(height: 20),
          _buildAiSummary(report),
          if (report.therapistNotes != null &&
              report.therapistNotes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildTherapistNotes(report.therapistNotes!),
          ],
          if (report.therapistFeedback.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildFeedbackSection(report),
          ],
        ],
      ),
    );

    return doc.save();
  }

  // ── Header ────────────────────────────────────────────────────

  static pw.Widget _buildHeader(ReportModel report, pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [_teal, _tealLight],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PhysioCare',
                style: pw.TextStyle(
                  font: pw.Font.helveticaBold(),
                  fontSize: 18,
                  color: _white,
                ),
              ),
              pw.Text(
                'Rehabilitation Progress Report',
                style: pw.TextStyle(fontSize: 10, color: _white),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                report.patientName,
                style: pw.TextStyle(
                  font: pw.Font.helveticaBold(),
                  fontSize: 12,
                  color: _white,
                ),
              ),
              pw.Text(
                'Dr. ${report.therapistName}',
                style: pw.TextStyle(fontSize: 10, color: _white),
              ),
              pw.Text(
                report.period.label,
                style: pw.TextStyle(fontSize: 10, color: _white),
              ),
              pw.Text(
                '${report.generatedAt.day.toString().padLeft(2, '0')}/'
                '${report.generatedAt.month.toString().padLeft(2, '0')}/'
                '${report.generatedAt.year}',
                style: pw.TextStyle(fontSize: 10, color: _white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────

  static pw.Widget _buildFooter(ReportModel report, pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated: ${_fmtDate(report.generatedAt)} • PhysioCare',
            style: pw.TextStyle(fontSize: 9, color: _sub),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: _sub),
          ),
        ],
      ),
    );
  }

  // ── Therapist details card ────────────────────────────────

  static pw.Widget _buildTherapistCard(ReportModel report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _bg,
        border: pw.Border.all(color: _teal, width: 1.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Assigned Physiotherapist',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 10,
              color: _teal,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left — identity
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      report.therapistName,
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 14,
                        color: _dark,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      report.therapistSpecialization.isNotEmpty
                          ? report.therapistSpecialization
                          : 'Physiotherapist',
                      style: pw.TextStyle(fontSize: 10, color: _sub),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      report.therapistExperienceYears > 0
                          ? '${report.therapistExperienceYears} years of experience'
                          : 'Experience: Not specified',
                      style: pw.TextStyle(fontSize: 10, color: _sub),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              // Right — contact
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _therapistInfoRow(
                      'Phone',
                      report.therapistPhone.isNotEmpty
                          ? report.therapistPhone
                          : 'Not provided',
                    ),
                    pw.SizedBox(height: 6),
                    _therapistInfoRow(
                      'Clinic',
                      report.therapistClinicAddress.isNotEmpty
                          ? report.therapistClinicAddress
                          : 'Not provided',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _therapistInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(
            font: pw.Font.helveticaBold(),
            fontSize: 9,
            color: _sub,
          ),
        ),
        pw.Expanded(
          child: pw.Text(value, style: pw.TextStyle(fontSize: 9, color: _dark)),
        ),
      ],
    );
  }

  // ── Stats banner ──────────────────────────────────────────────

  static pw.Widget _buildStatsBanner(ReportModel report) {
    final stats = [
      ('Sessions', report.totalSessions.toString()),
      ('Total Reps', report.totalReps.toString()),
      ('Exercise Time', '${report.totalMinutes} min'),
      ('Avg Reps', report.avgReps.toStringAsFixed(1)),
      ('Avg Accuracy', '${report.avgAccuracy.toStringAsFixed(1)}%'),
      ('Best Session', '${report.bestReps} reps'),
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _bg,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _teal, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary Statistics',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 13,
              color: _dark,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${report.patientName}  •  ${report.condition}  •  Trend: ${report.progressTrend}',
            style: pw.TextStyle(fontSize: 10, color: _sub),
          ),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: stats.map((s) {
              return pw.Container(
                width: 100,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: _teal,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      s.$2,
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 16,
                        color: _white,
                      ),
                    ),
                    pw.Text(
                      s.$1,
                      style: pw.TextStyle(fontSize: 9, color: _white),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Exercise breakdown ────────────────────────────────────────

  static pw.Widget _buildExerciseBreakdown(ReportModel report) {
    if (report.exerciseBreakdown.isEmpty) return pw.SizedBox();
    final total = report.exerciseBreakdown.values.fold(0, (a, b) => a + b);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Exercise Breakdown'),
        pw.SizedBox(height: 8),
        ...report.exerciseBreakdown.entries.map((entry) {
          final pct = total == 0 ? 0.0 : entry.value / total;
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      entry.key,
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 11,
                        color: _dark,
                      ),
                    ),
                    pw.Text(
                      '${entry.value} reps  (${(pct * 100).toStringAsFixed(0)}%)',
                      style: pw.TextStyle(fontSize: 10, color: _sub),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Stack(
                  children: [
                    pw.Container(
                      height: 8,
                      decoration: pw.BoxDecoration(
                        color: const PdfColor(0.886, 0.906, 0.941),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                    ),
                    pw.Container(
                      height: 8,
                      width: 460 * pct, // A4 content width ≈ 460pt
                      decoration: pw.BoxDecoration(
                        color: _teal,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Bar chart ─────────────────────────────────────────────────

  static pw.Widget _buildBarChart(ReportModel report) {
    final recent = report.sessions.reversed.take(12).toList();
    if (recent.isEmpty) return pw.SizedBox();

    final maxReps = recent
        .map((s) => s.repsDone)
        .reduce((a, b) => a > b ? a : b);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Reps Per Session (last ${recent.length})'),
        pw.SizedBox(height: 8),
        pw.Container(
          height: 100,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: recent.map((s) {
              final pct = maxReps == 0 ? 0.0 : s.repsDone / maxReps;
              final abbr = s.exerciseTitle.length >= 2
                  ? s.exerciseTitle.substring(0, 2).toUpperCase()
                  : s.exerciseTitle.toUpperCase();
              return pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        '${s.repsDone}',
                        style: pw.TextStyle(fontSize: 7, color: _dark),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        height: 80 * pct + 4,
                        decoration: pw.BoxDecoration(
                          color: _teal,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        abbr,
                        style: pw.TextStyle(fontSize: 7, color: _sub),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Session table ─────────────────────────────────────────────

  static pw.Widget _buildSessionTable(ReportModel report) {
    if (report.sessions.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Session History'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder(
            bottom: pw.BorderSide(color: _sub, width: 0.5),
            horizontalInside: pw.BorderSide(color: _bg, width: 0.5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(0.9),
            2: const pw.FlexColumnWidth(2.0),
            3: const pw.FlexColumnWidth(0.7),
            4: const pw.FlexColumnWidth(1.0),
            5: const pw.FlexColumnWidth(1.0),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _bg),
              children:
                  ['Date', 'Time', 'Exercise', 'Reps', 'Duration', 'Accuracy']
                      .map(
                        (h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          child: pw.Text(
                            h,
                            style: pw.TextStyle(
                              font: pw.Font.helveticaBold(),
                              fontSize: 9,
                              color: _sub,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
            // Data rows
            ...report.sessions.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final bg = i.isEven ? _white : _bg;
              final acc = s.accuracy;
              final accColor = acc >= 80
                  ? _green
                  : acc >= 60
                  ? _amber
                  : _red;
              final accBg = acc >= 80
                  ? const PdfColor(0.133, 0.773, 0.369, 0.15)
                  : acc >= 60
                  ? const PdfColor(0.961, 0.620, 0.043, 0.15)
                  : const PdfColor(0.937, 0.267, 0.267, 0.15);

              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bg),
                children: [
                  _tCell(_fmtDate(s.createdAt.toLocal())),
                  _tCell(_fmtTime(s.createdAt.toLocal())),
                  _tCell(s.exerciseTitle),
                  _tCell(s.repsDone.toString()),
                  _tCell('${(s.durationSeconds / 60).toStringAsFixed(1)} min'),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: pw.BoxDecoration(
                        color: accBg,
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Text(
                        '${acc.toStringAsFixed(0)}%',
                        style: pw.TextStyle(
                          font: pw.Font.helveticaBold(),
                          fontSize: 9,
                          color: accColor,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── AI Summary ────────────────────────────────────────────────

  static pw.Widget _buildAiSummary(ReportModel report) {
    if (report.aiSummary.isEmpty) return pw.SizedBox();

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _white,
        border: pw.Border.all(color: _teal, width: 1.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'AI Clinical Assessment',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 12,
              color: _teal,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            report.aiSummary,
            style: pw.TextStyle(fontSize: 10, color: _dark, lineSpacing: 4),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'AI-generated note. Not a substitute for professional clinical judgement.',
            style: pw.TextStyle(
              fontSize: 8,
              color: _sub,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ── Therapist notes ───────────────────────────────────────────

  static pw.Widget _buildTherapistNotes(String notes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _amberBg,
        border: pw.Border.all(color: _amber, width: 1.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Clinical Notes',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 12,
              color: _amber,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            notes,
            style: pw.TextStyle(fontSize: 10, color: _dark, lineSpacing: 4),
          ),
        ],
      ),
    );
  }

  // ── Therapist feedback ────────────────────────────────────────

  static pw.Widget _buildFeedbackSection(ReportModel report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Therapist Feedback'),
        pw.SizedBox(height: 8),
        ...report.therapistFeedback.take(5).map((f) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _amberBg,
                border: pw.Border.all(color: _amber, width: 0.8),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    f.message,
                    style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: 10,
                      color: _dark,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    _fmtDate(f.createdAt.toLocal()),
                    style: pw.TextStyle(fontSize: 8, color: _sub),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Shared helpers ────────────────────────────────────────────

  static pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        font: pw.Font.helveticaBold(),
        fontSize: 13,
        color: _dark,
      ),
    );
  }

  static pw.Widget _tCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, color: _dark)),
    );
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
