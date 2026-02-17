import 'package:flutter/material.dart';

import '../pose_detector/camera_pose_view.dart';

class ExerciseSessionScreen extends StatefulWidget {
  const ExerciseSessionScreen({super.key});

  @override
  State<ExerciseSessionScreen> createState() => _ExerciseSessionScreenState();
}

class _ExerciseSessionScreenState extends State<ExerciseSessionScreen> {
  bool _audioEnabled = true;

  // Demo reps for now
  int _currentRep = 0;
  final int _targetReps = 10;

  ExerciseType _exercise = ExerciseType.bicepCurl;

  static const Color kPrimary = Color(0xFF1FC7B6);
  static const Color kBg = Color(0xFFF8FAFC);
  static const Color kTextDark = Color(0xFF0F172A);
  static const Color kSub = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 900;

    return Scaffold(
      backgroundColor: kBg,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              _exerciseTitle(_exercise),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              "Rep $_currentRep of $_targetReps",
              style: const TextStyle(fontSize: 12, color: kSub),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Audio",
            onPressed: () {
              setState(() => _audioEnabled = !_audioEnabled);
            },
            icon: Icon(
              _audioEnabled
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: isWide ? _wideLayout() : _mobileBlocked(),
          ),
        ),
      ),

      // Bottom controls
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CircleButton(
              bg: Colors.red,
              icon: Icons.stop,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(width: 16),
            _CircleButton(
              bg: Colors.white,
              icon: Icons.pause,
              iconColor: kTextDark,
              border: true,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Pause clicked (TODO)")),
                );
              },
            ),
            const SizedBox(width: 16),
            _CircleButton(
              bg: Colors.white,
              icon: Icons.chat_bubble_outline,
              iconColor: kTextDark,
              border: true,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Chat clicked (TODO)")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =============================
  // WEB/TABLET LAYOUT ONLY
  // =============================
  Widget _wideLayout() {
    return Row(
      children: [
        Expanded(child: _cameraPanel()),
        const SizedBox(width: 16),
        Expanded(child: _referencePanel()),
      ],
    );
  }

  // =============================
  // MOBILE BLOCKED VIEW
  // =============================
  Widget _mobileBlocked() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.desktop_windows, size: 44, color: kSub),
          SizedBox(height: 14),
          Text(
            "Web Mode Only",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: kTextDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "This exercise session layout is designed for Web/Tablet.\n\nOpen PhysioCare on a wider screen to continue.",
            textAlign: TextAlign.center,
            style: TextStyle(color: kSub),
          ),
        ],
      ),
    );
  }

  // =============================
  // CAMERA PANEL
  // =============================
  Widget _cameraPanel() {
    return _PanelCard(
      label: "Your Camera",
      topRightWidget: DropdownButtonHideUnderline(
        child: DropdownButton<ExerciseType>(
          value: _exercise,
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: kTextDark,
            fontWeight: FontWeight.w700,
          ),
          items: const [
            DropdownMenuItem(
              value: ExerciseType.bicepCurl,
              child: Text("Bicep Curl"),
            ),
            DropdownMenuItem(
              value: ExerciseType.sideRaise,
              child: Text("Side Raise"),
            ),
          ],
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              _exercise = val;
              _currentRep = 0; // demo reset
            });
          },
        ),
      ),
      child: CameraPoseView(
        showOverlayUI: false,
        initialExercise: _exercise,
      ),
    );
  }

  // =============================
  // REFERENCE PANEL
  // =============================
  Widget _referencePanel() {
    return _PanelCard(
      label: "Reference Video",
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 90,
                width: 90,
                decoration: const BoxDecoration(
                  color: kPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow,
                    size: 48, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                "Reference Video",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Follow this movement",
                style: TextStyle(color: kSub),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Play reference video (TODO)")),
                  );
                },
                child: const Text(
                  "Play",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _exerciseTitle(ExerciseType ex) {
    switch (ex) {
      case ExerciseType.bicepCurl:
        return "Bicep Curl";
      case ExerciseType.sideRaise:
        return "Side Raise";
      case ExerciseType.squats:
        return "Squats";
    }
  }
}

// =============================
// COMMON PANEL CARD
// =============================
class _PanelCard extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? topRightWidget;

  const _PanelCard({
    required this.label,
    required this.child,
    this.topRightWidget,
  });

  static const Color kTextDark = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (topRightWidget != null) topRightWidget!,
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================
// CIRCLE BUTTON
// =============================
class _CircleButton extends StatelessWidget {
  final Color bg;
  final IconData icon;
  final Color iconColor;
  final bool border;
  final VoidCallback onTap;

  const _CircleButton({
    required this.bg,
    required this.icon,
    this.iconColor = Colors.white,
    this.border = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          height: 62,
          width: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: border ? Border.all(color: Colors.black12) : null,
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
      ),
    );
  }
}