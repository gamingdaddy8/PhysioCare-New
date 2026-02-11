import 'package:flutter/material.dart';
import 'app/app.dart';
import 'config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseConfig.init();

  runApp(const PhysioCareApp());
}
