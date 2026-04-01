// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class WebCameraPreview extends StatelessWidget {
  final String viewId;

  const WebCameraPreview({super.key, required this.viewId});

  static final Set<String> _registered = {};

  void _register() {
    if (_registered.contains(viewId)) return;
    _registered.add(viewId);

    ui.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final video = web.HTMLVideoElement()
        ..id = viewId
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(-1)'; // mirror the video feed for natural feel

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