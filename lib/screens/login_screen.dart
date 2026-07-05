import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'admin_main_screen.dart';
import 'main_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Email / password sign-in ──────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await _auth.signIn(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;

      // Route based on role: admins go to AdminMainScreen.
      final role = await _auth.getUserRole();
      if (!mounted) return;
      final dest = role == 'admin'
          ? const AdminMainScreen()
          : const MainScreen();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => dest),
        (r) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  // ── Demo bypass ───────────────────────────────────────────────────────────

  void _demoLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (r) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  static const _kWaveH   = 140.0;
  static const _kLogoD   = 96.0;  // logo circle diameter

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Wave + overlapping logo circle ──────────────────────────────
          SizedBox(
            height: _kWaveH + _kLogoD / 2,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Wave — same shape & gradient as Home
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: ClipPath(
                    clipper: AppWaveClipper(),
                    child: Container(
                      height: _kWaveH,
                      decoration: const BoxDecoration(gradient: kHeaderGradient),
                    ),
                  ),
                ),
                // "Waby" wordmark inside the wave
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: const Text(
                        'Waby',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                // Logo circle — overlaps the wave bottom edge
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: _kLogoD,
                    height: _kLogoD,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Image.asset(
                      'assets/images/Waby_Logo_clean.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.child_care,
                          size: 40,
                          color: AppColors.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable form ─────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Heading
                    const Center(
                      child: Text('Welcome back!',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy)),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text('Sign in to continue',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 24),

                    // Email
                    _fieldLabel('Email'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _fieldDecoration(
                        hint: 'you@email.com',
                        prefix: Icons.email_outlined,
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    _fieldLabel('Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: _fieldDecoration(
                        hint: '••••••••',
                        prefix: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Minimum 6 characters'
                          : null,
                    ),

                    // Error banner
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      AuthErrorBanner(_error!),
                    ],

                    const SizedBox(height: 24),

                    // Primary login button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Sign In',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Demo mode
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _demoLogin,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: AppColors.navy.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          foregroundColor: AppColors.navy,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Demo Mode',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Register link
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        ),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary),
                            children: [
                              TextSpan(text: "Don't have an account? "),
                              TextSpan(
                                text: 'Register',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.textPrimary));

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.field,
      prefixIcon: Icon(prefix, color: AppColors.textSecondary, size: 20),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

