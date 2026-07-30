import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../models/contact.dart';
import '../models/seat_status.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import '../services/alert_feedback_service.dart';
import '../services/contact_service.dart';
import '../services/family_service.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/contact_status_badge.dart';
import '../widgets/invite_family_sheet.dart';
import '../widgets/signed_avatar.dart';
import 'car_settings_screen.dart';
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
  double _alertTimer  = 60;  // seconds
  String _displayName = 'Account owner';
  String? _avatarPath;
  int? _memberCount;
  int? _contactCount;

  final _auth = AuthService();
  final _familyService = FamilyService();

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
    _loadAvatarPath();
    _loadMemberCount();
    _loadAlertTimer();
    _loadReminderPreferences();
  }

  Future<void> _loadReminderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _appAlerts = prefs.getBool(kPushNotificationsPrefKey) ?? true;
      _vibration = prefs.getBool(kVibrationPrefKey) ?? true;
      _audibleWarn = prefs.getBool(kSoundPrefKey) ?? false;
    });
  }

  Future<void> _setReminderPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _loadDisplayName() async {
    final name = await _auth.getDisplayName();
    if (mounted) setState(() => _displayName = name);
  }

  Future<void> _loadAvatarPath() async {
    final data = await _auth.getProfile();
    final path = data?['avatar_path'] as String?;
    if (mounted) setState(() => _avatarPath = path);
  }

  Future<void> _loadAlertTimer() async {
    final data = await _auth.getProfile();
    final seconds = data?['alert_timer_seconds'] as int?;
    if (mounted && seconds != null) {
      setState(() => _alertTimer = seconds.toDouble());
    }
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
  static const _kCardRadius = 16.0;
  static const _kRowV = 14.0; // vertical padding per row
  static const _kIconSize = 44.0;
  // Light-blue chip tint derived from theme
  static const _kIconBg = Color(0xFFD4EEF8);
  // Same page grey used by Profile / Privacy / Help (Home/Family content surface)
  static const _kScaffoldBg = Color(0xFFF4F6F9);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kScaffoldBg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(context),

                  // ── Reminder preferences ───────────────────────────────
                  _sectionLabel('Reminder preferences'),
                  _card([
                    _toggleRow(
                      Icons.notifications_none_rounded,
                      'Push notifications',
                      'Show a banner and lock-screen notification when the app is in the background.',
                      _appAlerts,
                      (v) async {
                        setState(() => _appAlerts = v);
                        await _setReminderPreference(
                            kPushNotificationsPrefKey, v);
                      },
                    ),
                    _divider(),
                    _toggleRow(
                      Icons.vibration_rounded,
                      'Vibration',
                      'Vibrate the phone when a caution reminder fires.',
                      _vibration,
                      (v) async {
                        setState(() => _vibration = v);
                        await _setReminderPreference(kVibrationPrefKey, v);
                      },
                    ),
                    _divider(),
                    _toggleRow(
                      Icons.volume_up_rounded,
                      'Sound',
                      'Play the alert tone when a caution reminder fires.',
                      _audibleWarn,
                      (v) async {
                        setState(() => _audibleWarn = v);
                        await _setReminderPreference(kSoundPrefKey, v);
                      },
                    ),
                    _divider(),
                    _navRow(Icons.send_outlined, 'Send Test Notification',
                        onTap: () async {
                      await AlertService.instance.sendTestNotification();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test notification sent'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }),
                    _divider(),
                    _navRow(Icons.crop_din_outlined, 'Test Alert Screens',
                        onTap: () => showModalBottomSheet<void>(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: Wrap(
                                  children: [
                                    ListTile(
                                      leading: const Icon(
                                          Icons.person_off_outlined),
                                      title: const Text('Left Behind'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        AlertService.instance.fireTestAlert(
                                            AlertReason.leftBehind);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                          Icons.thermostat_outlined),
                                      title: const Text('Heat'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        AlertService.instance
                                            .fireTestAlert(AlertReason.heat);
                                      },
                                    ),
                                    ListTile(
                                      leading:
                                          const Icon(Icons.link_outlined),
                                      title: const Text('Buckle Reminder'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        AlertService.instance.fireTestAlert(
                                            AlertReason.buckleReminder);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            )),
                  ]),

                  // ── Distance Setting ───────────────────────────────────
                  _sectionLabel('Distance Setting'),
                  _card([
                    _sliderRow(
                      icon: Icons.social_distance_outlined,
                      label: 'Far Distance Alert',
                      value: _distance,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      badgeText: '${_distance.round()} m',
                      onChanged: (v) => setState(() => _distance = v),
                    ),
                    _divider(),
                    _sliderRow(
                      icon: Icons.timer_outlined,
                      label: 'Auto-alert timer',
                      value: _alertTimer,
                      min: 30,
                      max: 90,
                      divisions: 12,
                      badgeText: '${_alertTimer.round()} sec',
                      onChanged: (v) async {
                        setState(() => _alertTimer = v);
                        await _auth.updateAlertTimerSeconds(v.round());
                        await AlertService.instance
                            .refreshAlertTimerSetting();
                      },
                    ),
                  ]),

                  // ── Access ──────────────────────────────────────────────
                  _sectionLabel('Access'),
                  _card([
                    _navRow(Icons.people_outlined, 'Family Management',
                        subtitle: _memberSubtitle,
                        onTap: () => _showFamilyManagement()),
                    _divider(),
                    _navRow(Icons.directions_car_outlined, 'Car Profiles',
                        onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const CarSettingsScreen()),
                            )),
                  ]),

                  // ── Support & Safety ───────────────────────────────────
                  _sectionLabel('Support & Safety'),
                  _card([
                    _navRow(Icons.shield_outlined, 'Privacy & Data',
                        onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const PrivacyDataScreen()),
                            )),
                    _divider(),
                    _navRow(Icons.help_outline, 'Help & Support',
                        onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const HelpSupportScreen()),
                            )),
                  ]),
                  const SizedBox(height: 32),

                  // ── Sign Out ───────────────────────────────────────────
                  _buildSignOut(),
                  const SizedBox(height: 12),
                  _buildDeleteAccount(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header (shared wave — identical to Family & Car Profiles) ─────────────

  Widget _buildHeader() {
    return const SharedPageHeader(title: 'Settings', showBack: false);
  }

  // ── Profile card ──────────────────────────────────────────────────────────

  Widget _buildProfileCard(BuildContext context) {
    return _cardContainer(
      child: InkWell(
        borderRadius: BorderRadius.circular(_kCardRadius),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
          _loadDisplayName();
          _loadAvatarPath();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: _kRowV),
          child: Row(
            children: [
              SignedAvatar(
                photoPath: _avatarPath,
                radius: 24,
                backgroundColor: AppColors.accent,
                fallbackIcon: Icons.person,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_displayName,
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy)),
                    const SizedBox(height: 2),
                    Text('Account owner',
                        style: GoogleFonts.poppins(
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
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
      ),
    );
  }

  // ── Card wrapper ──────────────────────────────────────────────────────────

  Widget _card(List<Widget> rows) {
    return _cardContainer(child: Column(children: rows));
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: child,
      ),
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: Color(0x11000000),
      );

  // ── Toggle row ────────────────────────────────────────────────────────────

  Widget _toggleRow(
    IconData icon,
    String label,
    String infoBody,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: _kRowV),
      child: Row(
        children: [
          _iconBubble(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tight(const Size(20, 20)),
                  onPressed: () => _showToggleInfo(context, label, infoBody),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.dot,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD1D5DB),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Future<void> _showToggleInfo(
    BuildContext context,
    String title,
    String firstParagraph,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(
          '$firstParagraph\n\nSafety warnings — heat, left-behind — always sound and vibrate even when this is off.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
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
      padding: const EdgeInsets.fromLTRB(16, _kRowV, 16, 8),
      child: Column(
        children: [
          // ── Top row: icon + label + value badge ──
          Row(
            children: [
              _iconBubble(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.poppins(
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
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: _kRowV),
        child: Row(
          children: [
            _iconBubble(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: GoogleFonts.poppins(
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
    return SizedBox(
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Text('Sign Out',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteAccount() {
    return SizedBox(
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_forever,
                size: 20, color: AppColors.warning),
            const SizedBox(width: 10),
            Text('Delete Account',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning)),
          ],
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
  late Future<Map<String, dynamic>> _familyDataFuture;

  @override
  void initState() {
    super.initState();
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

  void _openInvite() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      useSafeArea: true,
      builder: (sheetCtx) => InviteFamilySheet(
        onInvite: (name, phone, relation) async {
          await _service.addContact(
              name: name, phone: phone, relation: relation);
          if (sheetCtx.mounted) {
            Navigator.pop(sheetCtx);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$name added as an emergency contact')),
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
          // title
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
                        String msg =
                            'Family members who have joined using your Family Join Code.';
                        if (snap.hasData) {
                          final ownerId =
                              snap.data!['ownerId']?.toString();
                          final myId = snap.data!['myId']?.toString();
                          final isOwner =
                              myId != null && myId == ownerId;
                          msg = isOwner
                              ? 'Members who joined using your Family Join Code. Only you can remove them.'
                              : 'Members who joined using the Family Join Code.';
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
                          'No other family members yet. Share your Family Join Code from the Family page.',
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
                          final nick =
                              (m['nickname'] ?? '').toString().trim();
                          final full =
                              (m['full_name'] ?? '').toString().trim();
                          final display = nick.isNotEmpty
                              ? nick
                              : (full.isNotEmpty
                                  ? full
                                  : (m['email'] ?? 'Member').toString());
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
                                SignedAvatar(
                                  photoPath: m['avatar_path'] as String?,
                                  radius: 20,
                                  backgroundColor: AppColors.accent
                                      .withValues(alpha: 0.15),
                                  fallbackText: display.isNotEmpty
                                      ? display[0].toUpperCase()
                                      : '?',
                                  iconColor: AppColors.accent,
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Emergency Contacts',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openInvite,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                label: const Text('Add',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
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
                        'No emergency contacts yet. Tap Add to add one.',
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
