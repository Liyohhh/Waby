import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth = AuthService();

  int _step = 0; // 0 = email, 1 = code, 2 = new password
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.sendPasswordResetCode(email);
      if (!mounted) return;
      setState(() => _step = 1);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.verifyPasswordResetCode(
        email: _emailCtrl.text,
        token: code,
      );
      if (!mounted) return;
      setState(() => _step = 2);
    } on AuthException catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'That code is incorrect or has expired. Please try again.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'That code is incorrect or has expired. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.sendPasswordResetCode(_emailCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code sent.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not resend code. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePassword() async {
    final pass = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.updatePassword(pass);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Password updated',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.navy)),
          content: const Text(
            'Please sign in with your new password.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not update password. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _title => switch (_step) {
        1 => 'Enter Code',
        2 => 'New Password',
        _ => 'Reset Password',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SharedPageHeader(title: _title),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  ..._buildStepBody(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorBanner(_error!),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () {
                              if (_step == 0) {
                                _sendCode();
                              } else if (_step == 1) {
                                _verifyCode();
                              } else {
                                _updatePassword();
                              }
                            },
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
                          : Text(
                              _step == 0
                                  ? 'Send Code'
                                  : _step == 1
                                      ? 'Verify'
                                      : 'Update Password',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  if (_step == 1) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _loading ? null : _resendCode,
                        child: const Text('Resend code',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                  _step = 0;
                                  _error = null;
                                  _codeCtrl.clear();
                                }),
                        child: const Text('Change email',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStepBody() {
    switch (_step) {
      case 1:
        return [
          Text(
            'We sent a 6-digit code to ${_emailCtrl.text.trim()}. Enter it below.',
            style: const TextStyle(
                fontSize: 14, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _fieldLabel('Code'),
          const SizedBox(height: 8),
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _fieldDecoration(
              hint: '123456',
              prefix: Icons.pin_outlined,
            ).copyWith(counterText: ''),
          ),
        ];
      case 2:
        return [
          const Text(
            'Choose a new password for your account.',
            style: TextStyle(
                fontSize: 14, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _fieldLabel('New password'),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePass,
            decoration: _fieldDecoration(
              hint: '••••••••',
              prefix: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _obscurePass ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePass = !_obscurePass),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Confirm password'),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            decoration: _fieldDecoration(
              hint: '••••••••',
              prefix: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
        ];
      default:
        return [
          const Text(
            "Enter your email and we'll send you a 6-digit code.",
            style: TextStyle(
                fontSize: 14, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _fieldLabel('Email'),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _fieldDecoration(
              hint: 'you@email.com',
              prefix: Icons.email_outlined,
            ),
          ),
        ];
    }
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
