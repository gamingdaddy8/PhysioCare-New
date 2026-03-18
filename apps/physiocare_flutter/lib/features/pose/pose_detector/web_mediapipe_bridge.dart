import 'dart:convert';
import 'dart:js_interop';

@JS('startMediapipePose')
external JSPromise startMediapipePose(String videoId);

@JS('stopMediapipePose')
external void stopMediapipePose();

@JS('onPoseLandmarks')
external set onPoseLandmarks(JSFunction f);

class WebMediapipeBridge {
  static void init(void Function(List<dynamic> landmarks) onLandmarks) {
    onPoseLandmarks = ((JSAny? landmarks) {
      try {
        final dartObj = landmarks?.dartify();
        if (dartObj == null) return;
        final jsonString = jsonEncode(dartObj);
        final decoded = jsonDecode(jsonString) as List<dynamic>;
        onLandmarks(decoded);
      } catch (_) {}
    }).toJS;
  }
}