import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_gate.dart';
import '../screens/login_screen.dart';

class AppStart extends StatefulWidget {
  const AppStart({super.key});

  @override
  State<AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<AppStart> {
  static const _splashDuration = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(_splashDuration);
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    FlutterNativeSplash.remove();
    if (session != null) {
      await routeAfterAuth(context);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 256,
          child: Image(image: AssetImage('assets/images/Waby_Logo_clean.png')),
        ),
      ),
    );
  }
}
