import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';

/// Edit profile screen for the account owner (Mom / primary caregiver).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _relations = [
    'Parent',
    'Sibling',
    'Guardian',
    'Relative',
    'Other',
  ];

  static const _countries = [
    'Malaysia',
    'Singapore',
    'Indonesia',
    'Thailand',
    'Philippines',
    'Vietnam',
    'Brunei',
    'Myanmar',
    'Cambodia',
    'Laos',
    'Australia',
    'United Kingdom',
    'United States',
    'Canada',
    'Japan',
    'South Korea',
    'China',
    'India',
    'Saudi Arabia',
    'United Arab Emirates',
    'Qatar',
    'Kuwait',
    'Turkey',
    'Germany',
    'France',
    'Netherlands',
    'New Zealand',
    'Other',
  ];

  final _auth     = AuthService();
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _relation = 'Parent';
  String _country  = 'Malaysia';
  bool   _saving   = false;
  bool   _loading  = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _auth.getProfile();
      if (!mounted) return;
      if (data != null) {
        _nameCtrl.text = (data['full_name'] as String?) ?? '';
        _phoneCtrl.text = (data['phone'] as String?) ?? '';

        final relation = data['relation'] as String?;
        if (relation != null && _relations.contains(relation)) {
          _relation = relation;
        }
        final country = data['country'] as String?;
        if (country != null && _countries.contains(country)) {
          _country = country;
        }
      }

      if (_nameCtrl.text.trim().isEmpty) {
        final meta =
            (_auth.currentUser?.userMetadata?['full_name'] as String?)
                ?.trim();
        if (meta != null && meta.isNotEmpty) {
          _nameCtrl.text = meta;
        }
      }
    } catch (_) {
      // Leave fields blank on failure; user can still edit and save.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _auth.updateProfile(
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        relation: _relation,
        country: _country,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save profile. Please try again.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Generic bottom-sheet picker ─────────────────────────────────────────────

  Future<void> _pickOption({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PickerSheet(
        title: title,
        options: options,
        current: current,
        onSelected: (v) {
          onSelected(v);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          _ProfileHeader(onBack: () => Navigator.of(context).pop()),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Card 1: name + phone ──────────────────────────────
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
                    // ── Card 2: relation + country ────────────────────────
                    _card([
                      _selectRow(
                        label: 'Relationship to Child',
                        icon: Icons.favorite_border,
                        value: _relation,
                        onTap: () => _pickOption(
                          title: 'Relationship to Child',
                          options: _relations,
                          current: _relation,
                          onSelected: (v) => setState(() => _relation = v),
                        ),
                      ),
                      _divider(),
                      _selectRow(
                        label: 'Country',
                        icon: Icons.public_outlined,
                        value: _country,
                        onTap: () => _pickOption(
                          title: 'Country',
                          options: _countries,
                          current: _country,
                          onSelected: (v) => setState(() => _country = v),
                        ),
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

  // ── Reusable widgets ─────────────────────────────────────────────────────────

  Widget _card(List<Widget> children) => Container(
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

  Widget _divider() => const Divider(
      color: Colors.black12, height: 1, thickness: 1,
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
          _iconBubble(icon),
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

  Widget _selectRow({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _iconBubble(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _iconBubble(IconData icon) => Container(
        width: 36, height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFFD4EEF8),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.accent, size: 18),
      );
}

// ── Bottom-sheet picker ───────────────────────────────────────────────────────

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String current;
  final ValueChanged<String> onSelected;

  const _PickerSheet({
    required this.title,
    required this.options,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final opt = options[i];
                final selected = opt == current;
                return ListTile(
                  title: Text(opt,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected
                              ? AppColors.navy
                              : AppColors.textPrimary)),
                  trailing: selected
                      ? const Icon(Icons.check_circle,
                          color: AppColors.accent, size: 20)
                      : null,
                  onTap: () => onSelected(opt),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
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
          Positioned(
            bottom: 0, left: 0, right: 0,
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
