import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/auth_widgets.dart';

/// Edit profile screen for the account owner (Mom / primary caregiver).
/// Reached from Settings → Mom card and from Home → avatar.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController(text: 'Mom');
  final _phoneCtrl = TextEditingController(text: '+60 12 345 6789');
  final _relCtrl   = TextEditingController(text: 'Mother');
  final _countryCtrl = TextEditingController(text: 'Malaysia');

  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _relCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          // ── Wave header with avatar ──────────────────────────────────────
          _ProfileHeader(onBack: () => Navigator.of(context).pop()),
          // ── Form ────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _card([
                      _fieldRow(
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        controller: _nameCtrl,
                        hint: 'e.g. Sarah Tan',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                      ),
                      _divider(),
                      _fieldRow(
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        controller: _phoneCtrl,
                        hint: 'e.g. +60 12 345 6789',
                        keyboard: TextInputType.phone,
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _card([
                      _fieldRow(
                        label: 'Relationship to Child',
                        icon: Icons.favorite_border,
                        controller: _relCtrl,
                        hint: 'e.g. Mother, Father, Guardian',
                      ),
                      _divider(),
                      _fieldRow(
                        label: 'Country',
                        icon: Icons.public_outlined,
                        controller: _countryCtrl,
                        hint: 'e.g. Malaysia',
                      ),
                    ]),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 22, width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Save Changes',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() =>
      const Divider(color: Colors.black12, height: 1, thickness: 1,
          indent: 20, endIndent: 20);

  Widget _fieldRow({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFD4EEF8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboard,
              validator: validator,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                labelStyle: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile header (wave + overlapping avatar) ────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _ProfileHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Wave gradient
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipPath(
              clipper: AppWaveClipper(),
              child: Container(
                height: 150,
                decoration: const BoxDecoration(gradient: kHeaderGradient),
              ),
            ),
          ),
          // Back + title
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: onBack,
                    ),
                    const Text('Edit Profile',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          // Avatar overlapping wave bottom
          Positioned(
            bottom: 0,
            left: 0, right: 0,
            child: Center(
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4EEF8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.person, color: AppColors.accent,
                    size: 36),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
