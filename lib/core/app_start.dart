import 'package:flutter/material.dart';
import '../screens/login_screen.dart';

/// Branded splash shown for a fixed short duration, then straight to login.
///
/// No session or family lookup happens here — that runs after the user signs
/// in — so startup can never hang on a slow or stalled network call.
class AppStart extends StatefulWidget {
  const AppStart({super.key});

  @override
  State<AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<AppStart> {
  // How long the logo stays visible before routing to login (keep <= 2s).
  static const _splashDuration = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    _goToLogin();
  }

  Future<void> _goToLogin() async {
    await Future.delayed(_splashDuration);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // White background + smaller centred logo — matches the native splash.
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 120,
          child: Image(image: AssetImage('assets/images/Waby_Logo_clean.png')),
        ),
      ),
    );
  }
}
