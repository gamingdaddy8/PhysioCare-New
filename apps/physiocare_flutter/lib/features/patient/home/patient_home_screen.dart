import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  static const Color kPrimary = Color(0xFF1FC7B6);
  static const Color kDark = Color(0xFF0F172A);
  static const Color kSub = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Header(),
              const SizedBox(height: 25),
              const _MotivationBanner(),
              const SizedBox(height: 20),
              const _ProgressCard(),
              const SizedBox(height: 20),
              const _StreakCard(),
              const SizedBox(height: 25),
              const _SectionTitle("Today's Exercises"),
              const SizedBox(height: 15),
              const _ExerciseList(),
              const SizedBox(height: 25),
              const _PainTracker(),
              const SizedBox(height: 25),
              const _UpcomingAppointment(),
              const SizedBox(height: 25),
              const _ConnectedCareCard(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const _BottomNav(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        CircleAvatar(
          radius: 24,
          backgroundColor: PatientHomeScreen.kPrimary,
          child: Icon(Icons.person, color: Colors.white),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome Back 👋",
                  style: TextStyle(
                      fontSize: 14, color: PatientHomeScreen.kSub)),
              Text("Rohan",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: PatientHomeScreen.kDark)),
            ],
          ),
        ),
        Icon(Icons.notifications_none)
      ],
    );
  }
}

class _MotivationBanner extends StatelessWidget {
  const _MotivationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PatientHomeScreen.kPrimary, Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.emoji_events, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Keep going! You're closer to full recovery 💪",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          )
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text("Recovery Progress",
              style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: 0.7,
            backgroundColor: Colors.black12,
            valueColor:
                AlwaysStoppedAnimation(PatientHomeScreen.kPrimary),
          ),
          SizedBox(height: 10),
          Text("70% Completed",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: PatientHomeScreen.kPrimary)),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      child: Row(
        children: const [
          Icon(Icons.local_fire_department,
              color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Text("7 Day Exercise Streak 🔥",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: PatientHomeScreen.kDark)),
        ],
      ),
    );
  }
}

class _PainTracker extends StatelessWidget {
  const _PainTracker();

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text("Pain Level Today",
              style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 10),
          LinearProgressIndicator(
            value: 0.3,
            backgroundColor: Colors.black12,
            valueColor:
                AlwaysStoppedAnimation(Colors.redAccent),
          ),
          SizedBox(height: 8),
          Text("Mild Pain",
              style: TextStyle(color: Colors.redAccent)),
        ],
      ),
    );
  }
}

class _UpcomingAppointment extends StatelessWidget {
  const _UpcomingAppointment();

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      child: Row(
        children: const [
          Icon(Icons.calendar_today,
              color: PatientHomeScreen.kPrimary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Next Session: 18 Feb • 4:00 PM",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          )
        ],
      ),
    );
  }
}

class _ExerciseList extends StatelessWidget {
  const _ExerciseList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ExerciseCard("Back Stretch", Icons.self_improvement),
        SizedBox(height: 12),
        _ExerciseCard("Bridge Exercise", Icons.fitness_center),
        SizedBox(height: 12),
        _ExerciseCard("Arm Extension", Icons.accessibility_new),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final String title;
  final IconData icon;

  const _ExerciseCard(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      child: Row(
        children: [
          Icon(icon, color: PatientHomeScreen.kPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PatientHomeScreen.kPrimary,
            ),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.poseTest),
            child: const Text("Start"),
          )
        ],
      ),
    );
  }
}

class _ConnectedCareCard extends StatelessWidget {
  const _ConnectedCareCard();

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      child: const Text(
        "Your physiotherapist is actively monitoring your progress.",
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ModernCard extends StatelessWidget {
  final Widget child;
  const _ModernCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4))
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: PatientHomeScreen.kDark),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      selectedItemColor: PatientHomeScreen.kPrimary,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Progress"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}