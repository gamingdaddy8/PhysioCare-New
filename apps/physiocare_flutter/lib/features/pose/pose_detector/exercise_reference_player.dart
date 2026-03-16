import 'dart:ui_web' as ui;
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'exercise_type.dart';

/// Inline YouTube reference video player for web.
/// Uses HtmlElementView to embed YouTube iframe — no redirect, plays inline.
class ExerciseReferencePlayer extends StatefulWidget {
  final ExerciseType exercise;

  const ExerciseReferencePlayer({
    super.key,
    required this.exercise,
  });

  @override
  State<ExerciseReferencePlayer> createState() =>
      _ExerciseReferencePlayerState();
}

class _ExerciseReferencePlayerState
    extends State<ExerciseReferencePlayer> {
  static const Color kPrimary  = Color(0xFF1FC7B6);
  static const Color kTextDark = Color(0xFF0F172A);
  static const Color kSub      = Color(0xFF64748B);

  bool _showVideo = false;

  // YouTube video IDs for each exercise
  static const Map<ExerciseType, _VideoInfo> _videos = {
    ExerciseType.bicepCurl: _VideoInfo(
      videoId:     'ykJmrZ5v0Oo',
      title:       'Bicep Curl',
      description: 'Proper form — stand straight, curl arms up fully, lower slowly',
    ),
    ExerciseType.sideRaise: _VideoInfo(
      videoId:     '3VcKaXpzqRo',
      title:       'Side Raise',
      description: 'Raise arms sideways to shoulder height, keep elbows slightly bent',
    ),
    ExerciseType.squats: _VideoInfo(
      videoId:     'aclHkVaku9U',
      title:       'Bodyweight Squat',
      description: 'Feet shoulder-width, lower hips until thighs parallel to floor',
    ),
  };

  // Unique view ID per exercise to avoid iframe conflicts
  String get _viewId =>
      'yt-player-${widget.exercise.name}-${hashCode}';

  void _registerIframe() {
    if (!kIsWeb) return;

    final info = _videos[widget.exercise]!;
    final src  =
        'https://www.youtube.com/embed/${info.videoId}'
        '?autoplay=1&rel=0&modestbranding=1&playsinline=1';

    ui.platformViewRegistry.registerViewFactory(
      _viewId,
      (int id) => html.IFrameElement()
        ..src = src
        ..style.border = 'none'
        ..style.width  = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..setAttribute('allow',
            'accelerometer; autoplay; clipboard-write; '
            'encrypted-media; gyroscope; picture-in-picture'),
    );
  }

  @override
  void initState() {
    super.initState();
    if (_showVideo) _registerIframe();
  }

  @override
  Widget build(BuildContext context) {
    final info = _videos[widget.exercise] ??
        _videos[ExerciseType.bicepCurl]!;

    if (!kIsWeb) {
      return _buildUnsupportedCard(info);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _showVideo
          ? _buildVideoPlayer(info)
          : _buildThumbnail(info),
    );
  }

  Widget _buildThumbnail(_VideoInfo info) {
    return Container(
      key: const ValueKey('thumbnail'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // YouTube thumbnail preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  'https://img.youtube.com/vi/${info.videoId}/hqdefault.jpg',
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: const Color(0xFF0F172A),
                    child: const Icon(Icons.play_circle_outline,
                        color: Colors.white54, size: 60),
                  ),
                ),
                // Play button overlay
                GestureDetector(
                  onTap: _onPlayTapped,
                  child: Container(
                    height: 60,
                    width: 60,
                    decoration: const BoxDecoration(
                      color: kPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 32),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Reference: ${info.title}',
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: kTextDark,
                fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            info.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: kSub, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _onPlayTapped,
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Watch Reference',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(_VideoInfo info) {
    return Container(
      key: const ValueKey('player'),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          // Video iframe
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              child: HtmlElementView(viewType: _viewId),
            ),
          ),
          // Close bar
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.play_circle_outline,
                    color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Text(
                  info.title,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showVideo = false),
                  icon: const Icon(Icons.close,
                      color: Colors.white54, size: 16),
                  label: const Text('Close',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupportedCard(_VideoInfo info) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_outlined,
              size: 40, color: kSub),
          const SizedBox(height: 12),
          const Text('Reference video available on web only',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: kSub, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(info.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kSub, fontSize: 12)),
        ],
      ),
    );
  }

  void _onPlayTapped() {
    _registerIframe();
    setState(() => _showVideo = true);
  }
}

class _VideoInfo {
  final String videoId;
  final String title;
  final String description;

  const _VideoInfo({
    required this.videoId,
    required this.title,
    required this.description,
  });
}