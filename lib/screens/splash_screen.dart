import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import 'admin_main_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Shows the splash for a minimum duration, then routes: active session ->
  /// role-appropriate screen, otherwise -> login. Uses pushReplacement so the
  /// splash can't be returned to via the back button.
  Future<void> _bootstrap() async {
    // Run the minimum-display timer and the session/role lookup together.
    final results = await Future.wait([
      Future.delayed(const Duration(milliseconds: 1800)),
      _resolveDestination(),
    ]);

    if (!mounted) return;
    final dest = results[1] as Widget;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => dest),
    );
  }

  /// Determines where to send the user based on the current Supabase session.
  Future<Widget> _resolveDestination() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const LoginScreen();

    final role = await AuthService().getUserRole();
    return role == 'admin' ? const AdminMainScreen() : const MainScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kHeaderGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo
                Image.asset(
                  'assets/images/Waby_Logo_clean.png',
                  height: 150,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.child_care, size: 100, color: Colors.white),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Waby',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Smart Baby Car Seat Monitoring',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),

                const Spacer(flex: 2),

                // Loading indicator — splash advances on its own.
                const SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
