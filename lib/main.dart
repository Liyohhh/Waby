import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://pvafygrloelptlmnhfog.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2YWZ5Z3Jsb2VscHRsbW5oZm9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0OTI1NjQsImV4cCI6MjA5ODA2ODU2NH0.Ak3Iu6i9F0OzSFRgTfyzX8UtEIQbIe3Bz6gT_b1sI60',
  );
  runApp(const WabyApp());
}

class WabyApp extends StatelessWidget {
  const WabyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waby',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}

/// Shortcut to the Supabase client, usable anywhere in the app.
final supabase = Supabase.instance.client;