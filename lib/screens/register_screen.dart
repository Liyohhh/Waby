import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth_gate.dart';
import '../core/constants.dart';
import '../core/relations.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/phone_number_field.dart';
import '../widgets/picker_sheet.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth        = AuthService();

  bool   _loading        = false;
  bool   _obscurePass    = true;
  bool   _obscureConfirm = true;
  String  _relation      = kRelationOptions.first;
  String  _country       = 'Malaysia';
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Auth logic (unchanged) ────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final isActive = await _auth.signUp(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        nickname: _nicknameController.text.trim(),
        phone: _phoneController.text.trim(),
        relation: _relation,
        country: _country,
      );
      if (!mounted) return;

      if (isActive) {
        await routeAfterAuth(context);
      } else {
        setState(() { _loading = false; });
        _showConfirmationDialog();
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Registration failed. Please try again.';
        _loading = false;
      });
    }
  }

  void _showConfirmationDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Check your email',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
        content: const Text(
          'A confirmation link has been sent to your email address.\n\n'
          'Please open it, then come back and sign in.\n\n'
          'Tip: To skip this step during development, disable "Enable email '
          'confirmations" in your Supabase Authentication settings.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Go to Sign In',
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Design constants ──────────────────────────────────────────────────────

  static const _kWaveH = 140.0;
  static const _kLogoD = 96.0;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Wave + overlapping logo circle (identical to Login) ──────────
          SizedBox(
            height: _kWaveH + _kLogoD / 2,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Gradient wave
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

                // Back arrow + "Waby" wordmark inside the wave
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 24, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white, size: 22),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Text(
                            'Waby',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
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
                      errorBuilder: (_, _, _) => const Icon(
                          Icons.child_care,
                          size: 40,
                          color: AppColors.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable form ──────────────────────────────────────────────
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
                      child: Text('Create Account',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy)),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text('Join Waby today',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 24),

                    // Full Name
                    _fieldLabel('Full Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration(
                        hint: '',
                        prefix: Icons.person_outline,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Nickname (optional)
                    _fieldLabel('Nickname (optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nicknameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration(
                        hint: '',
                        prefix: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    _fieldLabel('Phone Number'),
                    const SizedBox(height: 8),
                    PhoneNumberField(
                      controller: _phoneController,
                      validator: (v) {
                        final digits = (v ?? '').trim();
                        if (digits.isEmpty) {
                          return 'Please enter a phone number';
                        }
                        if (digits.length < 7 || digits.length > 11) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Relation
                    _fieldLabel('Relationship to Child'),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => showPickerSheet(
                        context,
                        title: 'Relationship to Child',
                        options: kRelationOptions,
                        current: _relation,
                        onSelected: (v) => setState(() => _relation = v),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _fieldDecoration(
                          hint: '',
                          prefix: Icons.family_restroom_outlined,
                        ),
                        child: Text(_relation,
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Country
                    _fieldLabel('Country'),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => showPickerSheet(
                        context,
                        title: 'Country',
                        options: kCountryOptions,
                        current: _country,
                        onSelected: (v) => setState(() => _country = v),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _fieldDecoration(
                          hint: '',
                          prefix: Icons.public_outlined,
                        ),
                        child: Text(_country,
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Email
                    _fieldLabel('Email Address'),
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
                    const SizedBox(height: 4),
                    const Text('Minimum 6 characters',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      decoration: _fieldDecoration(
                        hint: '••••••••',
                        prefix: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Minimum 6 characters'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    _fieldLabel('Confirm Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      decoration: _fieldDecoration(
                        hint: '••••••••',
                        prefix: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) => v != _passCtrl.text
                          ? 'Passwords do not match'
                          : null,
                    ),

                    // Error banner
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      AuthErrorBanner(_error!),
                    ],

                    const SizedBox(height: 28),

                    // Primary Register button
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
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Register',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Already have an account? Login
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary),
                            children: [
                              TextSpan(text: 'Already have an account?  '),
                              TextSpan(
                                text: 'Login',
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textPrimary),
      );

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.field,
      isDense: true,
      prefixIcon: Icon(prefix, color: AppColors.textSecondary, size: 20),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}
