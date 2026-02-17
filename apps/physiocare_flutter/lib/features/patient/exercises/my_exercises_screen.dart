import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';

class MyExercisesScreen extends StatelessWidget {
  const MyExercisesScreen({super.key});

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
        title: const Text(
          "My Exercises",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
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
                const Text(
                  "0 exercises assigned",
                  style: TextStyle(color: kSub),
                ),
                const SizedBox(height: 14),

                // Search bar
                TextField(
                  decoration: InputDecoration(
                    hintText: "Search exercises...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Filter chip
                Wrap(
                  spacing: 10,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "All",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Empty state card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    children: const [
                      SizedBox(height: 10),
                      Text(
                        "No exercises found",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kTextDark,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Your physiotherapist hasn't assigned any exercises yet.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kSub),
                      ),
                      SizedBox(height: 12),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Demo button to open Pose Test screen
                if (!isWide)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.poseTest);
                      },
                      child: const Text(
                        "Open Exercise Camera (Demo)",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}