import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/contact.dart';
import '../services/auth_service.dart';
import '../services/contact_service.dart';
import '../widgets/invite_family_sheet.dart';
import 'help_support_screen.dart';
import 'login_screen.dart';
import 'privacy_data_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Local state ───────────────────────────────────────────────────────────
  bool _appAlerts     = true;
  bool _vibration     = true;
  bool _audibleWarn   = false;
  double _distance    = 2;   // meters
  double _alertTimer  = 1;   // minutes

  // ── Design constants ──────────────────────────────────────────────────────
  static const _kGutter        = 20.0;
  static const _kCardRadius    = 12.0;
  static const _kSectionGap    = 24.0;
  static const _kLabelCardGap  =  8.0;
  static const _kRowV          = 14.0;  // vertical padding per row
  static const _kIconSize      = 44.0;
  // Light-blue chip tint derived from theme
  static const _kIconBg = Color(0xFFD4EEF8);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: _kSectionGap),
            _buildProfileCard(context),
            const SizedBox(height: _kSectionGap),

            // ── Notifications ────────────────────────────────────────────
            _sectionLabel('Notifications'),
            const SizedBox(height: _kLabelCardGap),
            _card([
              _toggleRow(Icons.notifications_outlined, 'App Alerts',       _appAlerts,   (v) => setState(() => _appAlerts   = v)),
              _divider(),
              _toggleRow(Icons.vibration,              'Vibration',         _vibration,   (v) => setState(() => _vibration   = v)),
              _divider(),
              _toggleRow(Icons.volume_up_outlined,     'Audible Warning',   _audibleWarn, (v) => setState(() => _audibleWarn = v)),
            ]),
            const SizedBox(height: _kSectionGap),

            // ── Distance Setting ─────────────────────────────────────────
            _sectionLabel('Distance Setting'),
            const SizedBox(height: _kLabelCardGap),
            _card([
              _sliderRow(
                icon: Icons.social_distance_outlined,
                label: 'Far Distance Alert',
                value: _distance,
                min: 1, max: 5, divisions: 4,
                badgeText: '${_distance.round()} m',
                onChanged: (v) => setState(() => _distance = v),
              ),
              _divider(),
              _sliderRow(
                icon: Icons.timer_outlined,
                label: 'Auto-alert timer',
                value: _alertTimer,
                min: 1, max: 5, divisions: 4,
                badgeText: '${_alertTimer.round()} min',
                onChanged: (v) => setState(() => _alertTimer = v),
              ),
            ]),
            const SizedBox(height: _kSectionGap),

            // ── Connectivity & Access ─────────────────────────────────────
            _sectionLabel('Connectivity & Access'),
            const SizedBox(height: _kLabelCardGap),
            _card([
              _navRow(Icons.bluetooth,       'Bluetooth Devices',  subtitle: 'Not connected',
                  onTap: () => _showBluetoothDialog()),
              _divider(),
              _navRow(Icons.people_outlined, 'Family Management',  subtitle: '3 members',
                  onTap: () => _showFamilyManagement()),
            ]),
            const SizedBox(height: _kSectionGap),

            // ── Support & Safety ──────────────────────────────────────────
            _sectionLabel('Support & Safety'),
            const SizedBox(height: _kLabelCardGap),
            _card([
              _navRow(Icons.shield_outlined, 'Privacy & Data',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PrivacyDataScreen()),
                  )),
              _divider(),
              _navRow(Icons.help_outline, 'Help & Support',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const HelpSupportScreen()),
                  )),
            ]),
            const SizedBox(height: 32),

            // ── Sign Out ──────────────────────────────────────────────────
            _buildSignOut(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ── Header (wave — identical to Home & Family) ────────────────────────────

  Widget _buildHeader() {
    return Stack(
      children: [
        ClipPath(
          clipper: _WaveClipper(),
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: const BoxDecoration(gradient: kHeaderGradient),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_kGutter, 18, _kGutter, 0),
            child: const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Profile card ──────────────────────────────────────────────────────────

  Widget _buildProfileCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kGutter),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: _kGutter, vertical: _kRowV),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: _kIconBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person,
                        color: AppColors.accent, size: 30),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mom',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy)),
                        SizedBox(height: 2),
                        Text('Account owner',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kGutter),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ── Card wrapper ──────────────────────────────────────────────────────────

  Widget _card(List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kGutter),
      child: _cardContainer(child: Column(children: rows)),
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        thickness: 0.5,
        indent: _kGutter + _kIconSize + 14,
        endIndent: 0,
        color: Color(0xFFE5EAF0),
      );

  // ── Toggle row ────────────────────────────────────────────────────────────

  Widget _toggleRow(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: _kGutter, vertical: _kRowV),
      child: Row(
        children: [
          _iconBubble(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: AppColors.dot,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD1D5DB),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  // ── Slider row ────────────────────────────────────────────────────────────

  Widget _sliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String badgeText,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kGutter, _kRowV, _kGutter, 8),
      child: Column(
        children: [
          // ── Top row: icon + label + value badge ──
          Row(
            children: [
              _iconBubble(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          // ── Slider ──
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: AppColors.dot,
              inactiveTrackColor: const Color(0xFFD1D5DB),
              thumbColor: AppColors.accent,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
              overlayColor: AppColors.accent.withAlpha(30),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bluetooth dialog ──────────────────────────────────────────────────────

  void _showBluetoothDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: const [
          Icon(Icons.bluetooth, color: AppColors.accent, size: 22),
          SizedBox(width: 10),
          Text('Bluetooth Devices',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.bluetooth_disabled,
                      color: AppColors.textSecondary, size: 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text('No Bluetooth devices connected',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close',
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Family management sheet ───────────────────────────────────────────────

  void _showFamilyManagement() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FamilyManagementSheet(),
    );
  }

  // ── Nav row ───────────────────────────────────────────────────────────────

  Widget _navRow(IconData icon, String label,
      {String? subtitle, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_kCardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: _kGutter, vertical: _kRowV),
        child: Row(
          children: [
            _iconBubble(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }

  // ── Icon bubble ───────────────────────────────────────────────────────────

  Widget _iconBubble(IconData icon) {
    return Container(
      width: _kIconSize,
      height: _kIconSize,
      decoration: const BoxDecoration(
        color: _kIconBg,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.accent, size: 26),
    );
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  void _confirmSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign out?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'You will be returned to the welcome screen. Any unsaved changes will be lost.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await AuthService().signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Yes, sign out',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOut() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kGutter),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => _confirmSignOut(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_kCardRadius)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 20, color: Colors.white),
              SizedBox(width: 10),
              Text('Sign Out',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Family Management bottom sheet ───────────────────────────────────────────

class _FamilyManagementSheet extends StatefulWidget {
  const _FamilyManagementSheet();

  @override
  State<_FamilyManagementSheet> createState() =>
      _FamilyManagementSheetState();
}

class _FamilyManagementSheetState extends State<_FamilyManagementSheet> {
  final _service = ContactService();

  void _openInvite() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      useSafeArea: true,
      builder: (sheetCtx) => InviteFamilySheet(
        joinCode: 'BT - 8942',
        onInvite: (name, email, phone, relation) async {
          await _service.addContact(
              name: name, phone: phone, relation: relation);
          if (sheetCtx.mounted) {
            Navigator.pop(sheetCtx);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$name added to family')),
            );
            setState(() {});
          }
        },
      ),
    );
  }

  void _openEdit(Contact c) {
    final nameCtrl = TextEditingController(text: c.name);
    final phoneCtrl = TextEditingController(text: c.phone);
    final relCtrl = TextEditingController(text: c.relation);

    showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Member',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.navy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(hintText: 'Name')),
            const SizedBox(height: 12),
            TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(hintText: 'Phone number')),
            const SizedBox(height: 12),
            TextField(
                controller: relCtrl,
                decoration: const InputDecoration(
                    hintText: 'Relation (e.g. Dad, Aunt)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(88, 44)),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              final rel = relCtrl.text.trim();
              if (name.isEmpty || phone.isEmpty) return;
              await _service.updateContact(Contact(
                  id: c.id, name: name, phone: phone, relation: rel));
              if (d.mounted) Navigator.pop(d);
              if (mounted) setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Contact c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove member?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Remove ${c.name} from your family group?',
            style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Remove',
                style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteContact(c.id);
      if (mounted) setState(() {});
    }
  }

  void _showMemberOptions(Contact c) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: AppColors.accent),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _openEdit(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.warning),
              title: const Text('Remove',
                  style: TextStyle(color: AppColors.warning)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDelete(c);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // title + add button
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Family Management',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy)),
                    SizedBox(height: 2),
                    Text('Add, edit, or remove family members.',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openInvite,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.person_add_outlined, size: 16),
                label: const Text('Add',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),

            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<Contact>>(
            stream: _service.contactsStream(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final contacts = snap.data ?? [];
              if (contacts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No family members yet. Tap Add to invite.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),
                );
              }
              return Column(
                children: List.generate(contacts.length, (i) {
                  final c = contacts[i];
                  return Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.accent,
                            child: Text(
                              c.name.isNotEmpty
                                  ? c.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500)),
                                Text(c.relation,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert,
                                color: AppColors.textSecondary),
                            onPressed: () =>
                                _showMemberOptions(c),
                          ),
                        ],
                      ),
                      if (i < contacts.length - 1)
                        const Divider(
                            color: Colors.black12,
                            height: 1,
                            thickness: 1),
                    ],
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Wave clipper (identical to Home & Family) ─────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final h = size.height;
    final w = size.width;
    final path = Path()
      ..lineTo(0, h - 10)
      ..cubicTo(w * 0.12, h - 10, w * 0.20, h - 22, w * 0.32, h - 18)
      ..cubicTo(w * 0.40, h - 14, w * 0.47, h - 8,  w * 0.54, h - 10)
      ..cubicTo(w * 0.61, h - 12, w * 0.70, h - 26, w * 0.82, h - 22)
      ..cubicTo(w * 0.90, h - 18, w * 0.96, h - 12, w,        h - 12)
      ..lineTo(w, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
