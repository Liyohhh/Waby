import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/contact.dart';
import '../services/auth_service.dart';
import '../services/contact_service.dart';
import '../services/family_service.dart';
import '../widgets/contact_status_badge.dart';
import '../widgets/invite_family_sheet.dart';
import 'existing_or_new_family_screen.dart';
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
  String _displayName = 'Account owner';
  int? _memberCount;
  int? _contactCount;

  final _auth = AuthService();
  final _familyService = FamilyService();

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
    _loadMemberCount();
  }

  Future<void> _loadDisplayName() async {
    final name = await _auth.getDisplayName();
    if (mounted) setState(() => _displayName = name);
  }

  Future<void> _loadMemberCount() async {
    final members = await _familyService.fetchFamilyMembers();
    final contacts = await ContactService().contactsCount();
    if (mounted) {
      setState(() {
        _memberCount = members.length;
        _contactCount = contacts;
      });
    }
  }

  String get _memberSubtitle {
    final m = _memberCount;
    final c = _contactCount;
    if (m == null) return 'Loading…';
    final parts = <String>['$m member${m == 1 ? '' : 's'}'];
    if ((c ?? 0) > 0) parts.add('$c contact${c == 1 ? '' : 's'}');
    return parts.join(' · ');
  }

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
              _navRow(Icons.people_outlined, 'Family Management',
                  subtitle: _memberSubtitle,
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
            const SizedBox(height: 12),
            _buildDeleteAccount(),
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
      child: _cardContainer(
        child: InkWell(
          borderRadius: BorderRadius.circular(_kCardRadius),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
            _loadDisplayName();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: _kGutter, vertical: _kRowV),
            child: Row(
              children: [
                _iconBubble(Icons.person),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy)),
                      const SizedBox(height: 2),
                      const Text('Account owner',
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

  // ── Family management sheet ───────────────────────────────────────────────

  void _showFamilyManagement() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FamilyManagementSheet(),
    ).then((_) {
      if (mounted) _loadMemberCount();
    });
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

  void _confirmDeleteAccount(BuildContext context) {
    final confirmCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete account?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your account and cannot be undone. '
              'If you own a family, ownership will transfer to another '
              'member, or the family will be dissolved if you\'re the only '
              'one in it.\n\nType DELETE to confirm.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              decoration: const InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                if (confirmCtrl.text.trim() != 'DELETE') return;
                Navigator.of(dialogContext).pop();
                try {
                  await AuthService().deleteAccount();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not delete account: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete permanently',
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

  Widget _buildDeleteAccount() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kGutter),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: () => _confirmDeleteAccount(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.warning,
            side: const BorderSide(color: AppColors.warning),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_kCardRadius)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_forever, size: 20, color: AppColors.warning),
              SizedBox(width: 10),
              Text('Delete Account',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning)),
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
  late final Stream<List<Contact>> _contactsStream = _service.contactsStream();
  final _familyService = FamilyService();
  String? _joinCode;
  bool _loadingCode = true;
  late Future<Map<String, dynamic>> _familyDataFuture;

  @override
  void initState() {
    super.initState();
    _loadJoinCode();
    _familyDataFuture = _familyService.fetchFamilyData();
  }

  void _refreshFamilyData() {
    setState(() {
      _familyDataFuture = _familyService.fetchFamilyData();
    });
  }

  Future<void> _confirmRemove(String targetId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member'),
        content: Text(
          'Remove $name from your family? They will lose access to all shared data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _familyService.removeFamilyMember(targetId);
      _refreshFamilyData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $e')),
        );
      }
    }
  }

  Future<void> _confirmRemoveContact(Contact c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove contact'),
        content: Text(
          'Remove ${c.name} from emergency contacts? '
          'They will stop receiving Telegram alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteContact(c.id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${c.name} removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $e')),
        );
      }
    }
  }

  Future<void> _confirmLeaveFamily({required bool isOwner}) async {
    final content = isOwner
        ? 'As the owner, leaving will transfer ownership to another family '
          'member if one exists. If you\'re the only member, the family and '
          'all its shared data (children, devices, contacts) will be '
          'permanently deleted.'
        : 'You will lose access to all shared devices and children.';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave family'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Leave',
              style: TextStyle(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _familyService.leaveFamily();
      if (!mounted) return;
      Navigator.of(context).pop(); // close family management sheet
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ExistingOrNewFamilyScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not leave family: $e')),
        );
      }
    }
  }

  Future<void> _loadJoinCode() async {
    final code = await _familyService.getInviteCode();
    if (mounted) {
      setState(() {
        _joinCode = code;
        _loadingCode = false;
      });
    }
  }

  void _openInvite() {
    if (_joinCode == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      useSafeArea: true,
      builder: (sheetCtx) => InviteFamilySheet(
        joinCode: _joinCode!,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Family Management',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy)),
                    const SizedBox(height: 2),
                    FutureBuilder<Map<String, dynamic>>(
                      future: _familyDataFuture,
                      builder: (context, snap) {
                        String msg = 'Manage your family members.';
                        if (snap.hasData) {
                          final ownerId =
                              snap.data!['ownerId']?.toString();
                          final myId = snap.data!['myId']?.toString();
                          final isOwner =
                              myId != null && myId == ownerId;
                          msg = isOwner
                              ? 'Invite or remove family members.'
                              : 'Invite members. Only the owner can remove.';
                        }
                        return Text(
                          msg,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
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
                      horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
          FutureBuilder<Map<String, dynamic>>(
            future: _familyDataFuture,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final data = snap.data!;
              final members = List<Map<String, dynamic>>.from(
                  data['members'] as List);
              final ownerId = data['ownerId']?.toString();
              final myId = data['myId']?.toString();
              final isOwner = myId != null && myId == ownerId;
              final memberContent = members.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No family members yet. Tap Add to invite.',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${members.length} member${members.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...members.map((m) {
                          final name =
                              (m['full_name'] ?? '').toString().trim();
                          final display = name.isNotEmpty
                              ? name
                              : (m['email'] ?? 'Member').toString();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFE5EAF0)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.accent
                                      .withValues(alpha: 0.15),
                                  child: Text(
                                    display.isNotEmpty
                                        ? display[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          display,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (m['id']?.toString() == myId) ...[
                                        const SizedBox(width: 6),
                                        const Text(
                                          '(me)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isOwner &&
                                    m['id']?.toString() != ownerId)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.person_remove,
                                      size: 20,
                                      color: AppColors.warning,
                                    ),
                                    tooltip: 'Remove member',
                                    onPressed: () => _confirmRemove(
                                      m['id'].toString(),
                                      display,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );

              return memberContent;
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Emergency Contacts',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _familyDataFuture,
            builder: (context, familySnap) {
              var isOwner = false;
              if (familySnap.hasData) {
                final ownerId = familySnap.data!['ownerId']?.toString();
                final myId = familySnap.data!['myId']?.toString();
                isOwner = myId != null && myId == ownerId;
              }
              return StreamBuilder<List<Contact>>(
                stream: _contactsStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Could not load emergency contacts.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }
                  final contacts = snap.data ?? [];
                  if (contacts.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No emergency contacts yet. Tap Add to invite.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: contacts.map((c) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFE5EAF0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.accent
                                  .withValues(alpha: 0.15),
                              child: const Icon(
                                Icons.person_outline,
                                size: 20,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (c.relation.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      c.relation,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ContactStatusBadge(linked: c.isLinked),
                            if (isOwner)
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: AppColors.warning,
                                ),
                                tooltip: 'Remove contact',
                                onPressed: () =>
                                    _confirmRemoveContact(c),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),
          const Divider(color: Color(0xFFE5EAF0), height: 1),
          const SizedBox(height: 20),
          FutureBuilder<Map<String, dynamic>>(
            future: _familyDataFuture,
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final data = snap.data!;
              final ownerId = data['ownerId']?.toString();
              final myId = data['myId']?.toString();
              if (myId == null) return const SizedBox.shrink();
              return Center(
                child: TextButton.icon(
                  icon: const Icon(
                    Icons.exit_to_app,
                    color: AppColors.warning,
                  ),
                  label: const Text(
                    'Leave family',
                    style: TextStyle(color: AppColors.warning),
                  ),
                  onPressed: () =>
                      _confirmLeaveFamily(isOwner: myId == ownerId),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
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
