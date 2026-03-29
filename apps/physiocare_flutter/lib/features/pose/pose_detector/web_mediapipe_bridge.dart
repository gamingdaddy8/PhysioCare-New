import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

// ── JS external declarations ──────────────────────────────────

@JS('startMediapipePose')
external void startMediapipePose(String videoId);

@JS('stopMediapipePose')
external void stopMediapipePose();

// ── Bridge class ──────────────────────────────────────────────

class WebMediapipeBridge {
  static void init(
      void Function(List<Map<String, double>>) onLandmarks) {
    if (!kIsWeb) return;

    globalContext['onPoseLandmarks'] = ((JSArray jsArr) {
      try {
        final int length = jsArr.length;
        final List<Map<String, double>> result = [];

        for (int i = 0; i < length; i++) {
          final item = jsArr.getProperty<JSObject>(i.toJS);
          result.add({
            'x':          _num(item, 'x'),
            'y':          _num(item, 'y'),
            'z':          _num(item, 'z'),
            'visibility': _num(item, 'visibility'),
          });
        }

        onLandmarks(result);
      } catch (e) {
        debugPrint('WebMediapipeBridge error: $e');
      }
    }.toJS);
  }

  static double _num(JSObject obj, String key) {
    final val = obj.getProperty<JSAny?>(key.toJS);
    if (val == null) return 0.0;
    // JSNumber.toDartDouble is the correct Dart 3 API
    return (val as JSNumber).toDartDouble;
  }
}