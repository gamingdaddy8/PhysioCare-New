import 'package:flutter/material.dart';
import '../core/routes/app_routes.dart';
import 'app_theme.dart';

class PhysioCareApp extends StatelessWidget {
  const PhysioCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "PhysioCare",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
