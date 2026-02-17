import 'dart:convert';
import 'package:js/js.dart';

@JS('startMediapipePose')
external Future<void> startMediapipePose(String videoId);

@JS('stopMediapipePose')
external void stopMediapipePose();

@JS('onPoseLandmarks')
external set onPoseLandmarks(dynamic f);

class WebMediapipeBridge {
  static void init(void Function(List<dynamic> landmarks) onLandmarks) {
    onPoseLandmarks = allowInteropCaptureThis((_, landmarks) {
      try {
        final jsonString = jsonEncode(landmarks);
        final decoded = jsonDecode(jsonString) as List<dynamic>;
        onLandmarks(decoded);
      } catch (_) {}
    });
  }
}