import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/report_model.dart';
import '../models/report_period.dart';

class AiSummaryService {
  final String apiKey;

  AiSummaryService({required this.apiKey});

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  Future<String> generateSummary(ReportModel report) async {
    if (report.totalSessions == 0) {
      return 'No session data available for this period. '
          'The patient has not yet completed any exercises.';
    }

    // Skip API call if no key configured
    if (apiKey.isEmpty) return _fallback(report);

    try {
      final response = await http
          .post(
            Uri.parse('$_endpoint?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': _buildPrompt(report)},
                  ],
                },
              ],
              'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 300},
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text']?.toString().trim() ?? '';
            if (text.isNotEmpty) return text;
          }
        }
      }
    } catch (_) {
      // Timeout or network error — fall through to fallback
    }

    return _fallback(report);
  }

  String _buildPrompt(ReportModel report) {
    final sessionLines = report.sessions
        .take(10)
        .map(
          (s) =>
              '- ${s.exerciseTitle}: ${s.repsDone} reps, '
              '${(s.durationSeconds / 60).toStringAsFixed(1)} min, '
              '${s.accuracy.toStringAsFixed(0)}% accuracy',
        )
        .join('\n');

    return '''
You are a physiotherapy assistant generating a brief clinical progress note.
Write exactly 3-4 sentences. Be factual, clinical, and encouraging.
Do not use bullet points. Do not use markdown.

Patient: ${report.patientName}
Condition: ${report.condition}
Report Period: ${report.period.label}
Total Sessions: ${report.totalSessions}
Total Reps: ${report.totalReps}
Total Exercise Time: ${report.totalMinutes} minutes
Average Reps/Session: ${report.avgReps.toStringAsFixed(1)}
Average Accuracy: ${report.avgAccuracy.toStringAsFixed(1)}%
Best Session: ${report.bestReps} reps
Progress Trend: ${report.progressTrend}

Recent sessions:
$sessionLines

Write the clinical progress note now:
''';
  }

  String _fallback(ReportModel report) {
    final trend = report.progressTrend;
    final trendText = trend == 'Improving'
        ? 'showing a positive upward trend'
        : trend == 'Declining'
        ? 'showing a slight decline that warrants attention'
        : 'maintaining a consistent level of performance';

    return '${report.patientName} completed ${report.totalSessions} '
        'session${report.totalSessions == 1 ? '' : 's'} during this period, '
        'accumulating ${report.totalReps} total repetitions over '
        '${report.totalMinutes} minutes of exercise. '
        'Average accuracy was ${report.avgAccuracy.toStringAsFixed(1)}%, '
        'with a best session of ${report.bestReps} reps. '
        'Overall progress is $trendText in rehabilitation. '
        'Continued adherence to the prescribed exercise plan is recommended.';
  }
}
