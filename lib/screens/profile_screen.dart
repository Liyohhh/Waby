import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/relations.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/family_service.dart';
import '../services/image_upload_service.dart';
import '../widgets/signed_avatar.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/phone_number_field.dart';
import '../widgets/picker_sheet.dart';

/// Edit profile screen for the account owner (Mom / primary caregiver).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth     = AuthService();
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nicknameController = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _relation = 'Parent';
  String _country  = 'Malaysia';
  bool   _saving   = false;
  bool   _loading  = true;

  String? _avatarPath;
  String? _avatarSignedUrl;
  File?   _avatarPreview;
  bool    _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameController.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _auth.getProfile();
      if (!mounted) return;
      if (data != null) {
        _nameCtrl.text = (data['full_name'] as String?) ?? '';
        _nicknameController.text = (data['nickname'] as String?) ?? '';
        _phoneCtrl.text = (data['phone'] as String?) ?? '';

        final relation = data['relation'] as String?;
        if (relation != null && kRelationOptions.contains(relation)) {
          _relation = relation;
        }
        final country = data['country'] as String?;
        if (country != null && kCountryOptions.contains(country)) {
          _country = country;
        }

        _avatarPath = data['avatar_path'] as String?;
        if (_avatarPath != null) {
          _avatarSignedUrl =
              await ImageUploadService().signedUrlFor(_avatarPath);
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
        nickname: _nicknameController.text.trim(),
        phone: _phoneCtrl.text.trim(),
        relation: _relation,
        country: _country,
      );

      // Keep the Home screen greeting in sync with the new nickname.
      final newNickname = _nicknameController.text.trim();
      AppState.greetingName.value =
          newNickname.isNotEmpty ? newNickname : null;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      AppState.mainTabIndex.value = 2; // Settings tab
      Navigator.of(context).pop();
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
  }) {
    return showPickerSheet(
      context,
      title: title,
      options: options,
      current: current,
      onSelected: onSelected,
    );
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (_avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.warning),
                title: const Text('Remove Photo',
                    style: TextStyle(color: AppColors.warning)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (source == null) return;

    if (source == 'remove') {
      final oldPath = _avatarPath;
      await _auth.updateAvatarPath(null);
      if (oldPath != null) SignedAvatar.invalidate(oldPath);
      if (!mounted) return;
      setState(() {
        _avatarPath = null;
        _avatarPreview = null;
        _avatarSignedUrl = null;
      });
      AppState.avatarPath.value = null;
      return;
    }

    final userId = _auth.currentUser?.id;
    final familyId = await FamilyService().myFamilyId();
    if (userId == null || familyId == null || !mounted) return;

    setState(() => _uploadingAvatar = true);

    final result = await ImageUploadService().pickCropAndUpload(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      familyId: familyId,
      entityType: 'profiles',
      entityId: userId,
    );

    if (result != null) {
      await _auth.updateAvatarPath(result.path);
      SignedAvatar.invalidate(result.path);
      AppState.avatarPath.value = result.path;
    }

    if (!mounted) return;
    setState(() {
      _uploadingAvatar = false;
      if (result != null) {
        _avatarPath = result.path;
        _avatarPreview = result.localFile;
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          _ProfileHeader(
            onBack: () => Navigator.of(context).pop(),
            onTapAvatar: _pickAvatar,
            uploading: _uploadingAvatar,
            localPreview: _avatarPreview,
            signedUrl: _avatarSignedUrl,
          ),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _iconBubble(Icons.email_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Email',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _auth.currentUser?.email ?? '—',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _divider(),
                      _fieldRow(
                        label: 'Nickname',
                        icon: Icons.badge_outlined,
                        controller: _nicknameController,
                        hint: 'What should we call you?',
                      ),
                      _divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _iconBubble(Icons.phone_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PhoneNumberField(
                                controller: _phoneCtrl,
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
                            ),
                          ],
                        ),
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
                          options: kRelationOptions,
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
                          options: kCountryOptions,
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

// ── Profile header (wave + overlapping avatar) ────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onTapAvatar;
  final bool uploading;
  final File? localPreview;
  final String? signedUrl;
  const _ProfileHeader({
    required this.onBack,
    required this.onTapAvatar,
    required this.uploading,
    this.localPreview,
    this.signedUrl,
  });

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
              child: GestureDetector(
                onTap: uploading ? null : onTapAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4EEF8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        image: localPreview != null
                            ? DecorationImage(
                                image: FileImage(localPreview!),
                                fit: BoxFit.cover)
                            : (signedUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(signedUrl!),
                                    fit: BoxFit.cover)
                                : null),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: uploading
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : (localPreview == null && signedUrl == null
                              ? const Icon(Icons.person,
                                  color: AppColors.accent, size: 36)
                              : null),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.navy,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 12, color: Colors.white),
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
}
