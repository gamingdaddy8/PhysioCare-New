import 'package:flutter/material.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  // Theme Colors (match your UI)
  static const Color kPrimary = Color(0xFF1FC7B6);
  static const Color kDarkText = Color(0xFF0F172A);
  static const Color kSubText = Color(0xFF64748B);
  static const Color kCardBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= 1000;
    final isTablet = w >= 700 && w < 1000;
    final isMobile = w < 700;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isMobile ? _MobileDrawer() : null,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Navbar(isDesktop: isDesktop, isTablet: isTablet),
          ),

          // HERO
          SliverToBoxAdapter(
            child: _HeroSection(isDesktop: isDesktop, isTablet: isTablet),
          ),

          // STATS
          SliverToBoxAdapter(
            child: _StatsSection(isMobile: isMobile),
          ),

          // FEATURES TITLE
          SliverToBoxAdapter(
            child: _SectionTitle(
              title: "Everything You Need to",
              highlight: "Recover Faster",
              subtitle:
                  "Our comprehensive platform combines AI technology with professional care for the best recovery experience.",
            ),
          ),

          // FEATURES CARDS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _FeaturesGrid(isMobile: isMobile, isTablet: isTablet),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 60)),

          // HOW IT WORKS
          SliverToBoxAdapter(
            child: _SectionTitle(
              title: "How It Works",
              highlight: "",
              subtitle:
                  "Getting started with PhysioCare is simple. Follow these steps to begin your recovery journey.",
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _HowItWorks(isMobile: isMobile),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _Navbar extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;

  const _Navbar({required this.isDesktop, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final isCompact = !isDesktop;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          if (isCompact)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),

          const _Logo(),

          const Spacer(),

          if (isDesktop) ...[
            _NavItem("Features"),
            _NavItem("How It Works"),
            _NavItem("Pricing"),
            const SizedBox(width: 20),
          ],

          TextButton(
            onPressed: () {
              // TODO: Navigate to Login
            },
            child: const Text(
              "Sign In",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _PrimaryButton(
            text: "Get Started",
            onTap: () {
              // TODO: Navigate to Register
            },
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: LandingScreen.kPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.monitor_heart, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          "PhysioCare",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: LandingScreen.kDarkText,
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final String text;
  const _NavItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextButton(
        onPressed: () {},
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: LandingScreen.kSubText,
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;

  const _HeroSection({required this.isDesktop, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.4,
          colors: [
            Color(0xFFE8FBF8),
            Colors.white,
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: LandingScreen.kPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  "AI-Powered Physiotherapy",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: LandingScreen.kPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Heading
              Text(
                "Your Personal",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 70 : (isTablet ? 52 : 38),
                  fontWeight: FontWeight.w900,
                  color: LandingScreen.kDarkText,
                  height: 1.05,
                ),
              ),
              Text(
                "PhysioCare Partner",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 70 : (isTablet ? 52 : 38),
                  fontWeight: FontWeight.w900,
                  color: LandingScreen.kPrimary,
                  height: 1.05,
                ),
              ),

              const SizedBox(height: 20),

              // Subtitle
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: const Text(
                  "AI-guided exercises with real-time pose detection. Track your progress, stay connected with your physiotherapist, and recover faster.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.6,
                    color: LandingScreen.kSubText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Buttons
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  _PrimaryBigButton(
                    text: "Get Started",
                    onTap: () {
                      // TODO: Navigate to Register
                    },
                  ),
                  _OutlineBigButton(
                    text: "Watch Demo",
                    onTap: () {
                      // TODO: Open demo dialog/video
                    },
                  ),
                ],
              ),

              SizedBox(height: w < 700 ? 40 : 55),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final bool isMobile;
  const _StatsSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 20,
            runSpacing: 22,
            children: const [
              _StatItem(value: "10K+", label: "Active Patients"),
              _StatItem(value: "500+", label: "Physiotherapists"),
              _StatItem(value: "95%", label: "Recovery Rate"),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: LandingScreen.kPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: LandingScreen.kSubText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String highlight;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.highlight,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= 1000;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: isDesktop ? 52 : 36,
                    fontWeight: FontWeight.w900,
                    color: LandingScreen.kDarkText,
                    height: 1.1,
                  ),
                  children: [
                    TextSpan(text: title),
                    if (highlight.isNotEmpty) const TextSpan(text: "\n"),
                    if (highlight.isNotEmpty)
                      TextSpan(
                        text: highlight,
                        style: const TextStyle(
                          color: LandingScreen.kPrimary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: LandingScreen.kSubText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturesGrid extends StatelessWidget {
  final bool isMobile;
  final bool isTablet;

  const _FeaturesGrid({required this.isMobile, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final columns = isMobile ? 1 : (isTablet ? 2 : 3);

    final items = const [
      _FeatureCard(
        icon: Icons.camera_alt_outlined,
        title: "AI Pose Detection",
        desc:
            "Real-time pose analysis using AI technology ensures you perform exercises correctly every time.",
      ),
      _FeatureCard(
        icon: Icons.chat_bubble_outline,
        title: "Live Feedback",
        desc:
            "Receive instant on-screen and audio guidance to perfect your form and maximize recovery.",
      ),
      _FeatureCard(
        icon: Icons.bar_chart_rounded,
        title: "Progress Tracking",
        desc:
            "Detailed session reports and analytics help you and your physiotherapist monitor your journey.",
      ),
      _FeatureCard(
        icon: Icons.notifications_none_rounded,
        title: "Smart Notifications",
        desc:
            "Stay on track with exercise reminders and alerts. Your physio gets notified of missed sessions.",
      ),
      _FeatureCard(
        icon: Icons.people_alt_outlined,
        title: "Connected Care",
        desc:
            "Seamless communication between patients, physiotherapists, and family members.",
      ),
      _FeatureCard(
        icon: Icons.shield_outlined,
        title: "Pain Reporting",
        desc:
            "Quick pain alerts to your physio and family ensure safety during every exercise session.",
      ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final spacing = 18.0;
            final totalSpacing = spacing * (columns - 1);
            final itemWidth = (constraints.maxWidth - totalSpacing) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: items
                  .map(
                    (e) => SizedBox(
                      width: itemWidth,
                      child: e,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LandingScreen.kCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: LandingScreen.kPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: LandingScreen.kPrimary, size: 28),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: LandingScreen.kDarkText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.7,
              color: LandingScreen.kSubText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  final bool isMobile;
  const _HowItWorks({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final items = const [
      _StepItem(
        number: "01",
        title: "Connect with Your Physio",
        desc:
            "Your physiotherapist creates your personalized exercise program based on your condition and goals.",
      ),
      _StepItem(
        number: "02",
        title: "Start Your Session",
        desc:
            "Open the app, select an exercise, and position yourself in front of your camera. The AI will guide you.",
      ),
      _StepItem(
        number: "03",
        title: "Get Real-Time Feedback",
        desc:
            "Our AI analyzes your movements and provides instant corrections through visual cues and audio guidance.",
      ),
      _StepItem(
        number: "04",
        title: "Track Your Progress",
        desc:
            "Review your session reports, see your improvement over time, and share results with your physio.",
      ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: items
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 26),
                  child: e,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String number;
  final String title;
  final String desc;

  const _StepItem({
    required this.number,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            color: LandingScreen.kPrimary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: LandingScreen.kDarkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.7,
                  color: LandingScreen.kSubText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.check_circle, color: Colors.green, size: 22),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _PrimaryButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: LandingScreen.kPrimary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: LandingScreen.kPrimary.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PrimaryBigButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _PrimaryBigButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        decoration: BoxDecoration(
          color: LandingScreen.kPrimary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: LandingScreen.kPrimary.withOpacity(0.25),
              blurRadius: 22,
              offset: const Offset(0, 12),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _OutlineBigButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _OutlineBigButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LandingScreen.kCardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded,
                color: LandingScreen.kDarkText),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                color: LandingScreen.kDarkText,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: _Logo(),
            ),
            const Divider(),
            ListTile(
              title: const Text("Features"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text("How It Works"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text("Pricing"),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
