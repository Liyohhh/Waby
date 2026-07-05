import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/auth_widgets.dart';

/// The single place to edit the mom's profile details.
/// Navigated to from the Settings card AND the Home header avatar.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _namCtrl   = TextEditingController(text: 'Mom');
  final _relCtrl   = TextEditingController(text: 'Mother');
  final _cntryCtrl = TextEditingController(text: 'Malaysia');

  bool _saving = false;

  @override
  void dispose() {
    _namCtrl.dispose();
    _relCtrl.dispose();
    _cntryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    // TODO: persist to Supabase profiles table when auth is wired.
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

  // ── Design constants ──────────────────────────────────────────────────────

  static const _kWaveH  = 140.0;
  static const _kAvatarD = 80.0;
  static const _kGutter  = 24.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Wave + avatar overlap ────────────────────────────────────────
          SizedBox(
            height: _kWaveH + _kAvatarD / 2,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Gradient wave
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: ClipPath(
                    clipper: AppWaveClipper(),
                    child: Container(
                      height: _kWaveH,
                      decoration:
                          const BoxDecoration(gradient: kHeaderGradient),
                    ),
                  ),
                ),
                // Back + title inside the wave
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Avatar circle overlapping wave bottom
                Container(
                  width: _kAvatarD,
                  height: _kAvatarD,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4EEF8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person,
                      color: AppColors.accent, size: 36),
                ),
              ],
            ),
          ),

          // ── Form ────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: _kGutter),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _fieldLabel('Full Name'),
                    const SizedBox(height: 8),
                    _field(
                      controller: _namCtrl,
                      hint: 'e.g. Sarah Tan',
                      icon: Icons.person_outline,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel('Relationship to Child'),
                    const SizedBox(height: 8),
                    _field(
                      controller: _relCtrl,
                      hint: 'e.g. Mother, Father, Guardian',
                      icon: Icons.favorite_border,
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel('Country'),
                    const SizedBox(height: 8),
                    _field(
                      controller: _cntryCtrl,
                      hint: 'e.g. Malaysia',
                      icon: Icons.public_outlined,
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Save Changes',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
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

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.navy),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.field,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
