import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_gate.dart';
import '../screens/login_screen.dart';

/// Resolves the first real screen immediately after the native splash — no
/// artificial delay and no in-app loading UI.
class AppStart extends StatefulWidget {
  const AppStart({super.key});

  @override
  State<AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<AppStart> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      await routeAfterAuth(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Blank white — matches native splash; navigation happens on first frame.
    return const Scaffold(backgroundColor: Colors.white);
  }
}
