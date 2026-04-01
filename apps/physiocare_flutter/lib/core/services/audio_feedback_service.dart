import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Cross-platform (Web + Android + iOS) Text-to-Speech service.
/// Use [AudioFeedbackService.instance] everywhere — never construct directly.
class AudioFeedbackService {
  AudioFeedbackService._();
  static final AudioFeedbackService instance = AudioFeedbackService._();

  final FlutterTts _tts = FlutterTts();

  bool _enabled = true;
  bool _initialized = false;

  // Cooldown prevents spamming the same guidance phrase every frame.
  DateTime _lastSpoken = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _guidanceCooldown = Duration(milliseconds: 1500);

  // Rep announcements bypass the cooldown so they always fire.
  DateTime _lastRepSpoken = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _repCooldown = Duration(milliseconds: 800);

  bool get enabled => _enabled;
  set enabled(bool v) {
    _enabled = v;
    if (!v) _tts.stop();
  }

  /// Call once when the session screen is shown.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(kIsWeb ? 0.95 : 0.9);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // On Web, pick the first English voice available for consistency.
      if (kIsWeb) {
        final voices = await _tts.getVoices as List?;
        if (voices != null) {
          final eng = voices.firstWhere(
            (v) => v is Map && (v['locale'] as String?)?.startsWith('en') == true,
            orElse: () => null,
          );
          if (eng != null && eng is Map) {
            await _tts.setVoice({'name': eng['name'], 'locale': eng['locale']});
          }
        }
      }
    } catch (e) {
      debugPrint('[AudioFeedbackService] init error: $e');
    }
  }

  /// Speak a form-guidance phrase (subject to 1.5 s cooldown).
  Future<void> speakGuidance(String text) async {
    if (!_enabled || text.trim().isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastSpoken) < _guidanceCooldown) return;
    _lastSpoken = now;
    await _doSpeak(text);
  }

  /// Speak a rep/milestone announcement (short cooldown, always interrupts).
  Future<void> speakRep(String text) async {
    if (!_enabled || text.trim().isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastRepSpoken) < _repCooldown) return;
    _lastRepSpoken = now;
    _lastSpoken = now; // also reset guidance cooldown so it doesn't bleed over
    await _doSpeak(text);
  }

  Future<void> _doSpeak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[AudioFeedbackService] speak error: $e');
    }
  }

  /// Immediately silence any ongoing speech.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Call in dispose() of the session screen.
  Future<void> disposeService() async {
    await stop();
  }
}
