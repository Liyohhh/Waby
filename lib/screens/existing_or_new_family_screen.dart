import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/auth_gate.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/family_service.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

class ExistingOrNewFamilyScreen extends StatelessWidget {
  const ExistingOrNewFamilyScreen({super.key});

  // ── Design constants (identical to Login / Register) ──────────────────────

  static const _kGutter = 30.0;
  static const _kWaveH  = 140.0;
  static const _kLogoD  = 96.0; // logo circle diameter

  // This screen is always reached via pushAndRemoveUntil (stack cleared), so
  // there's no previous route to pop to. "Back" here signs the user out and
  // returns them to Login, which is the only meaningful prior step.
  Future<void> _goBack(BuildContext context) async {
    try {
      await AuthService().signOut();
    } catch (_) {
      // Ignore sign-out errors — still route to Login below.
    }
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

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
                            tooltip: 'Back to sign in',
                            onPressed: () => _goBack(context),
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

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(_kGutter, 28, _kGutter, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hello,\nNice to meet you!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                      height: 0.94,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please select if you want to create a new family or '
                    "you've been invited to join your existing family",
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _FamilyOptionCard(
                    icon: Icons.family_restroom,
                    label: 'Create New Family',
                    onTap: () => _showCreateDialog(context),
                  ),
                  const SizedBox(height: 16),
                  _FamilyOptionCard(
                    icon: Icons.groups,
                    label: 'Join Existing Family',
                    onTap: () => _showJoinDialog(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _CreateFamilyDialog(
        onCreated: () async {
          if (context.mounted) await routeAfterAuth(context);
        },
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _JoinFamilyDialog(
        onJoined: () async {
          if (context.mounted) await routeAfterAuth(context);
        },
      ),
    );
  }
}

// ── Option card ───────────────────────────────────────────────────────────────

class _FamilyOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FamilyOptionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.navyDeep, size: 25),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Create family dialog ──────────────────────────────────────────────────────

class _CreateFamilyDialog extends StatefulWidget {
  final Future<void> Function() onCreated;

  const _CreateFamilyDialog({required this.onCreated});

  @override
  State<_CreateFamilyDialog> createState() => _CreateFamilyDialogState();
}

class _CreateFamilyDialogState extends State<_CreateFamilyDialog> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);
    try {
      await FamilyService().createFamily(name);
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onCreated();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create family. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Create New Family',
          style: TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.navy)),
      content: TextField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Family name',
          filled: true,
          fillColor: AppColors.field,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _loading ? null : _create(),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _create,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }
}

// ── Join family dialog ────────────────────────────────────────────────────────

class _JoinFamilyDialog extends StatefulWidget {
  final Future<void> Function() onJoined;

  const _JoinFamilyDialog({required this.onJoined});

  @override
  State<_JoinFamilyDialog> createState() => _JoinFamilyDialogState();
}

class _JoinFamilyDialogState extends State<_JoinFamilyDialog> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() => _loading = true);
    try {
      final familyName = await FamilyService().joinFamily(code);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pop();

      await showDialog<void>(
        context: navigator.context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Joined!',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.navy)),
          content: Text('You\'ve successfully joined "$familyName".'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await widget.onJoined();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid invite code'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Join Existing Family',
          style: TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.navy)),
      content: TextField(
        controller: _codeCtrl,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
          _UpperCaseTextFormatter(),
        ],
        decoration: InputDecoration(
          labelText: 'Invite code',
          hintText: 'e.g. WABY-8942',
          filled: true,
          fillColor: AppColors.field,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _loading ? null : _join(),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _join,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Join'),
        ),
      ],
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
