import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WebCameraPreview extends StatelessWidget {
  final String viewId;

  const WebCameraPreview({super.key, required this.viewId});

  static final Set<String> _registered = {};

  void _register() {
    if (_registered.contains(viewId)) return;
    _registered.add(viewId);

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final video = html.VideoElement()
        ..id = viewId
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      return video;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox();

    _register();

    return HtmlElementView(viewType: viewId);
  }
}