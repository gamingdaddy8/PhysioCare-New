import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';

class PatientPortalHomeScreen extends StatelessWidget {
  const PatientPortalHomeScreen({super.key});

  // Theme colors (matching your screenshots)
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
        titleSpacing: 18,
        title: const _TopTitle(),
        actions: [
          IconButton(
            tooltip: "Logout",
            onPressed: () {
              // Later: Supabase signOut
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.splash,
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Greeting(),
                const SizedBox(height: 18),

                _TodaySessionCard(isWide: isWide),
                const SizedBox(height: 18),

                _QuickActionsRow(isWide: isWide),
                const SizedBox(height: 18),

                Row(
                  children: [
                    const Text(
                      "Your Exercises",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kTextDark,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.patientExercises);
                      },
                      icon: const Icon(Icons.chevron_right),
                      label: const Text("View All"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                _EmptyExercisesCard(isWide: isWide),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopTitle extends StatelessWidget {
  const _TopTitle();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: PatientPortalHomeScreen.kPrimary,
          child: Icon(Icons.monitor_heart, color: Colors.white, size: 18),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "PhysioCare",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: PatientPortalHomeScreen.kTextDark,
              ),
            ),
            Text(
              "Patient Portal",
              style: TextStyle(
                fontSize: 12,
                color: PatientPortalHomeScreen.kSub,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Hello, rudresh!",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: PatientPortalHomeScreen.kTextDark,
          ),
        ),
        SizedBox(height: 6),
        Text(
          "Let's continue your recovery journey today.",
          style: TextStyle(
            fontSize: 15,
            color: PatientPortalHomeScreen.kSub,
          ),
        ),
      ],
    );
  }
}

class _TodaySessionCard extends StatelessWidget {
  final bool isWide;
  const _TodaySessionCard({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            PatientPortalHomeScreen.kPrimary,
            Color(0xFF21C6D6),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Sessions",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "0 completed",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "0 exercises assigned to you",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: PatientPortalHomeScreen.kTextDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.exerciseSession);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      "Start Session",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.trending_up, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final bool isWide;
  const _QuickActionsRow({required this.isWide});

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return const Row(
        children: [
          Expanded(
            child: _QuickActionCard(
              title: "Exercises",
              icon: Icons.play_arrow,
              route: AppRoutes.patientExercises,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: _QuickActionCard(
              title: "Reports",
              icon: Icons.description_outlined,
              route: AppRoutes.patientReports,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: _QuickActionCard(
              title: "Schedule",
              icon: Icons.calendar_month_outlined,
              route: AppRoutes.patientSchedule,
            ),
          ),
        ],
      );
    }

    // Mobile layout
    return const Column(
      children: [
        _QuickActionCard(
          title: "Exercises",
          icon: Icons.play_arrow,
          route: AppRoutes.patientExercises,
        ),
        SizedBox(height: 12),
        _QuickActionCard(
          title: "Reports",
          icon: Icons.description_outlined,
          route: AppRoutes.patientReports,
        ),
        SizedBox(height: 12),
        _QuickActionCard(
          title: "Schedule",
          icon: Icons.calendar_month_outlined,
          route: AppRoutes.patientSchedule,
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              Icon(icon, color: PatientPortalHomeScreen.kPrimary),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: PatientPortalHomeScreen.kTextDark,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyExercisesCard extends StatelessWidget {
  final bool isWide;
  const _EmptyExercisesCard({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: isWide
          ? Row(
              children: [
                Expanded(
                  child: _EmptyText(),
                ),
                const SizedBox(width: 18),
                _ReportPainButton(),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _EmptyText(),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: _ReportPainButton()),
              ],
            ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.monitor_heart_outlined,
            size: 40, color: PatientPortalHomeScreen.kSub),
        SizedBox(height: 10),
        Text(
          "No exercises assigned yet",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: PatientPortalHomeScreen.kTextDark,
          ),
        ),
        SizedBox(height: 6),
        Text(
          "Your physiotherapist will assign exercises for your recovery plan.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: PatientPortalHomeScreen.kSub,
          ),
        ),
      ],
    );
  }
}

class _ReportPainButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      ),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report Pain clicked (demo)")),
        );
      },
      icon: const Icon(Icons.error_outline),
      label: const Text(
        "Report Pain",
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}