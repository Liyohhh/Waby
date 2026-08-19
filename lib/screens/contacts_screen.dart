import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/child.dart';
import '../models/contact.dart';
import '../models/seat_status.dart';
import '../services/child_service.dart';
import '../services/contact_service.dart';
import '../services/device_service.dart';
import '../services/family_service.dart';
import '../services/image_upload_service.dart';
import '../services/live_service.dart';
import '../services/simulated_status_service.dart';
import '../services/temperature_history_service.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/contact_status_badge.dart';
import '../widgets/gender_selector.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/signed_avatar.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, this.showBack = true});

  final bool showBack;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final Future<String?> _inviteCode = FamilyService().getInviteCode();
  late Stream<List<Map<String, dynamic>>> _familyMembersStream =
      FamilyService().familyMembersStream();
  late Stream<List<Contact>> _contactsStream = ContactService().contactsStream();
  final GlobalKey<_ChildrenSectionState> _childrenKey =
      GlobalKey<_ChildrenSectionState>();

  void _reloadMembers() {
    setState(() {
      _familyMembersStream = FamilyService().familyMembersStream();
    });
  }

  void _reloadContacts() {
    setState(() {
      _contactsStream = ContactService().contactsStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          _reloadMembers();
          _reloadContacts();
          _childrenKey.currentState?.reload();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 14),
              _buildChildrenSection(context),
              const SizedBox(height: 16),
              _buildFamilyMembersSection(context),
              const SizedBox(height: 16),
              _buildEmergencyContactsSection(context),
              const SizedBox(height: 16),
              _buildJoinCodeCard(),
              const SizedBox(height: 88),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    // Family gets its own taller wave + lower title than Settings/other tabs.
    return SharedPageHeader(
      title: 'Family',
      showBack: widget.showBack,
    );
  }

  Widget _buildChildrenSection(BuildContext context) {
    return _ChildrenSection(key: _childrenKey);
  }

  // ── Family Members section — read-only, managed in Settings ───────────────

  void _showSectionInfo(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.navy)),
        content: Text(body,
            style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyMembersSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Family Members',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF031E2A))),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showSectionInfo(
                  context,
                  'Family Members',
                  'Family members are people who share your Waby family and '
                      'can see your children and devices in the app. To add or '
                      'remove members, go to Settings → Family Management.',
                ),
                child: Icon(Icons.info_outline,
                    size: 16, color: AppColors.accent.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _familyMembersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        const Text(
                          "Couldn't load family members.",
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _reloadMembers,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final members = snapshot.data ?? [];
              final currentUid = Supabase.instance.client.auth.currentUser?.id;
              if (members.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                        'No family members yet. Add them in Settings → Family Management.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),
                );
              }
              return ValueListenableBuilder<String?>(
                valueListenable: AppState.avatarPath,
                builder: (context, myAvatar, _) {
                  return Column(
                    children: List.generate(members.length, (i) {
                      final m = members[i];
                      final nick = (m['nickname'] ?? '').toString().trim();
                      final full = (m['full_name'] ?? '').toString().trim();
                      final display = nick.isNotEmpty
                          ? nick
                          : (full.isNotEmpty
                              ? full
                              : (m['email'] ?? 'Member').toString());
                      final rel = (m['relation'] ?? '').toString().trim();
                      final isMe = m['id']?.toString() == currentUid;
                      final dbAvatar = m['avatar_path'] as String?;
                      return Padding(
                        padding: EdgeInsets.only(
                            bottom: i < members.length - 1 ? 8 : 0),
                        child: _memberRow(
                          display,
                          subtitle: rel.isNotEmpty ? rel : 'Member',
                          verified: i == 0,
                          isMe: isMe,
                          avatarPath: isMe
                              ? (myAvatar ?? dbAvatar)
                              : dbAvatar,
                        ),
                      );
                    }),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Emergency Contacts — read-only; add/remove in Settings ────────────────

  Widget _buildEmergencyContactsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Emergency Contacts',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF031E2A),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showSectionInfo(
                  context,
                  'Emergency Contacts',
                  'Emergency contacts are notified via Telegram if an alert '
                      'escalates and no one responds in the app. They don\'t '
                      'need a Waby account. To add or remove contacts, go to '
                      'Settings → Family Management.',
                ),
                child: Icon(Icons.info_outline,
                    size: 16, color: AppColors.accent.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Contact>>(
            stream: _contactsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        const Text("Couldn't load emergency contacts.",
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextButton(
                            onPressed: _reloadContacts,
                            child: const Text('Retry')),
                      ],
                    ),
                  ),
                );
              }
              final contacts = snapshot.data ?? [];
              if (contacts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No emergency contacts yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),
                );
              }
              return Column(
                children: List.generate(contacts.length, (i) {
                  final c = contacts[i];
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: i < contacts.length - 1 ? 8 : 0),
                    child: _emergencyContactRow(context, c),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _emergencyContactRow(BuildContext context, Contact c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(36),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD4EEF8).withAlpha(180),
                ),
                child: InitialsAvatar(name: c.name, radius: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    if (c.relation.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        c.relation,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.navy.withAlpha(170),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ContactStatusBadge(linked: c.isLinked),
            ],
          ),
          if (!c.isLinked) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        c.linkCode,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: c.linkCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Code copied'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Icon(Icons.copy_rounded,
                            size: 14, color: AppColors.headerTop),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ask ${c.name} to send this code to @WabyBabyBot on Telegram',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.navy.withAlpha(160),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _memberRow(String display,
      {String? subtitle,
      bool verified = false,
      bool isMe = false,
      String? avatarPath}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(36),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD4EEF8).withAlpha(180),
            ),
            child: SignedAvatar(
              photoPath: avatarPath,
              radius: 20,
              backgroundColor: const Color(0xFFE8F6FB),
              iconColor: AppColors.navy,
              fallbackText: display.isNotEmpty ? display[0].toUpperCase() : '?',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(display,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy)),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Text('(me)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.navy.withAlpha(150))),
                    ],
                    if (verified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified,
                          size: 14, color: AppColors.headerTop),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.navy.withAlpha(170))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Family Join Code card ─────────────────────────────────────────────────

  Widget _buildJoinCodeCard() {
    return FutureBuilder<String?>(
      future: _inviteCode,
      builder: (context, snapshot) {
        final loading =
            snapshot.connectionState == ConnectionState.waiting;
        return _joinCodeCard(code: snapshot.data, loading: loading);
      },
    );
  }

  Widget _joinCodeCard({required String? code, required bool loading}) {
    final display = loading ? '••••••' : (code ?? '—');
    final canCopy = !loading && code != null;

    void copy() {
      if (!canCopy) return;
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copied'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    const navy = Color(0xFF0F2D54); // AppColors.navy — code text

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          // Same light teal as Home child-card headers / wave header family
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4DBAD4), Color(0xFFA8E0EF)],
            stops: [0.31, 0.88],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.headerTop.withAlpha(50),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Waby wave sweeping up to the top-right
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _JoinWavePainter(
                      back: Colors.white.withAlpha(22),
                      front: Colors.white.withAlpha(40),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Role 1: eyebrow label (metadata) ──
                    Text(
                      'FAMILY JOIN CODE',
                      style: TextStyle(
                        color: AppColors.navy.withAlpha(170),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ── Role 2 + 3: code (hero, navy on soft chip) + copy control ──
                    GestureDetector(
                      onTap: copy,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F8FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withAlpha(150),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  display,
                                  style: const TextStyle(
                                    color: navy,
                                    fontSize: 30,
                                    height: 1.0,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.0,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 17,
                                  color: canCopy
                                      ? AppColors.headerTop
                                      : AppColors.headerTop.withAlpha(90),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    color: canCopy
                                        ? AppColors.headerTop
                                        : AppColors.headerTop.withAlpha(90),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── Role 4: instruction (description only, no action) ──
                    Text(
                      'Share this code to add new family members.',
                      style: TextStyle(
                        color: AppColors.navy.withAlpha(170),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Translucent wave sweeping up toward the top-right of the Join Code card.
class _JoinWavePainter extends CustomPainter {
  const _JoinWavePainter({required this.back, required this.front});
  final Color back;
  final Color front;

  Path _wave(Size s, double dy) {
    final w = s.width;
    final h = s.height;
    return Path()
      ..moveTo(w, h * (0.72 + dy))
      ..cubicTo(w * 0.86, h * (0.62 + dy), w * 0.84, h * (0.44 + dy),
          w * 0.70, h * (0.38 + dy))
      ..cubicTo(w * 0.58, h * (0.33 + dy), w * 0.56, h * (0.18 + dy),
          w * 0.44, h * (0.12 + dy))
      ..cubicTo(w * 0.39, h * (0.09 + dy), w * 0.37, h * (0.03 + dy),
          w * 0.35, h * dy)
      ..lineTo(w, h * dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_wave(size, 0.06), Paint()..color = back);
    canvas.drawPath(_wave(size, 0.0), Paint()..color = front);
  }

  @override
  bool shouldRepaint(covariant _JoinWavePainter old) =>
      old.back != back || old.front != front;
}

// ── Children section (unchanged) ──────────────────────────────────────────────

// Returns a human-readable age string from a date of birth.
String _ageFromDob(DateTime dob) {
  final now = DateTime.now();
  int years  = now.year  - dob.year;
  int months = now.month - dob.month;
  if (now.day < dob.day) months--;
  if (months < 0) { years--; months += 12; }
  if (years > 0) return months > 0 ? '$years yr $months mo' : '$years yr';
  if (months > 0) return '$months mo';
  return '< 1 mo';
}

class _ChildProfile {
  _ChildProfile({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.dob,
    required this.battery,
    required this.isWarning,
    required this.temperature,
    required this.buckled,
    required this.distanceNear,
    this.gender,
    this.weightKg,
    this.heightCm,
    this.photoPath,
    this.hardwareLinked = false,
    this.createdAt,
  });

  final String id;
  final String deviceId;
  String name;
  DateTime dob;
  int battery;
  bool isWarning;
  double temperature;
  bool buckled;
  bool distanceNear;
  String? gender;
  double? weightKg;
  double? heightCm;
  String? photoPath;
  bool hardwareLinked;
  DateTime? createdAt;

  String get ageLabel => _ageFromDob(dob);
}

class _ChildrenSection extends StatefulWidget {
  const _ChildrenSection({super.key});

  @override
  State<_ChildrenSection> createState() => _ChildrenSectionState();
}

class _ChildrenSectionState extends State<_ChildrenSection> {
  final ChildService _childService = ChildService();
  final LiveService _liveService = LiveService();
  late Stream<List<Child>> _childrenStream = _childService.myChildrenStream();
  late final Stream<SeatStatus> _liveStream = _liveService.liveStream();

  void reload() {
    setState(() {
      _childrenStream = _childService.myChildrenStream();
    });
  }

  // Local overrides until stream reflects edits (name/dob/weight/height).
  final Map<String, _ChildProfile> _localOverrides = {};

  _ChildProfile _toProfile(Child c, List<Child> family, SeatStatus rawLive) {
    final status =
        SimulatedStatusService.instance.resolve(c, family, rawLive);
    final temperature = status.temperature;
    final buckled = status.buckled;
    final distanceNear = status.distanceNear;
    final battery = status.battery;
    final isWarning = status.severity == SeatSeverity.warning;
    final hardwareLinked =
        SimulatedStatusService.instance.usesHardware(c, family);

    if (_localOverrides.containsKey(c.id)) {
      final o = _localOverrides[c.id]!;
      return _ChildProfile(
        id: o.id,
        deviceId: c.deviceId,
        name: o.name,
        dob: o.dob,
        battery: battery,
        isWarning: isWarning,
        temperature: temperature,
        buckled: buckled,
        distanceNear: distanceNear,
        gender: o.gender,
        weightKg: o.weightKg,
        heightCm: o.heightCm,
        photoPath: o.photoPath ?? c.photoPath,
        hardwareLinked: hardwareLinked,
        createdAt: o.createdAt ?? c.createdAt,
      );
    }
    return _ChildProfile(
      id: c.id,
      deviceId: c.deviceId,
      name: c.name,
      dob: c.dob ?? DateTime(2024, 1, 1),
      battery: battery,
      isWarning: isWarning,
      temperature: temperature,
      buckled: buckled,
      distanceNear: distanceNear,
      gender: c.gender,
      weightKg: c.weightKg,
      heightCm: c.heightCm,
      photoPath: c.photoPath,
      hardwareLinked: hardwareLinked,
      createdAt: c.createdAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Children',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF031E2A))),
          const SizedBox(height: 12),
          StreamBuilder<SeatStatus>(
            stream: _liveStream,
            builder: (context, liveSnap) {
              final rawLive = liveSnap.data ?? SeatStatus.empty();
              return StreamBuilder<List<Child>>(
                stream: _childrenStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.accent),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Column(
                          children: [
                            const Text(
                              "Couldn't load children.",
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: reload,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final children = snap.data ?? [];
                  if (children.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No children yet. Add a device from Home to register a child.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return Column(
                    children: List.generate(children.length, (i) {
                      final profile = _toProfile(children[i], children, rawLive);
                      return Padding(
                        padding: EdgeInsets.only(
                            bottom: i < children.length - 1 ? 8 : 0),
                        child: _childCard(context, profile),
                      );
                    }),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _childCard(BuildContext context, _ChildProfile child) {
    final isGirl = child.gender == 'Girl';

    final bgColor = isGirl
        ? const Color(0xFFFCEAF2)
        : const Color(0xFFD7F1F8);
    final avatarBg = isGirl
        ? const Color(0xFFF5B4CD)
        : const Color(0xFF7FD0E4);
    final avatarRing = isGirl
        ? const Color(0xFFF5B4CD).withAlpha(120)
        : const Color(0xFF7FD0E4).withAlpha(120);
    final shadowBase = isGirl
        ? const Color(0xFFF5B4CD)
        : const Color(0xFF7FD0E4);

    return GestureDetector(
      onTap: () => _showChildDetail(context, child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowBase.withAlpha(50),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarRing,
              ),
              child: SignedAvatar(
                photoPath: child.photoPath,
                radius: 22,
                backgroundColor: avatarBg,
                iconColor: AppColors.navy,
                fallbackIcon: Icons.child_care,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Text(
                    child.ageLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy.withAlpha(225),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${child.temperature.toStringAsFixed(0)}°C',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: child.isWarning ? AppColors.warning : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  child.isWarning ? 'WARNING' : 'SAFE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: child.isWarning ? AppColors.warning : AppColors.safe,
                  ),
                ),
              ],
            ),
            _childOptionsButton(context, child),
          ],
        ),
      ),
    );
  }

  void _showChildDetail(BuildContext context, _ChildProfile child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      useSafeArea: true,
      builder: (_) => _ChildDetailSheet(child: child),
    );
  }

  Widget _childOptionsButton(BuildContext context, _ChildProfile child) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Color(0xFF031E2A), size: 20),
      padding: EdgeInsets.zero,
      offset: const Offset(0, 32),
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'edit') {
          _openEditChild(context, child);
        } else if (value == 'delete') {
          _confirmDeleteChild(context, child);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'edit',
          height: 44,
          child: Row(
            children: const [
              Icon(Icons.edit_outlined, color: AppColors.accent, size: 20),
              SizedBox(width: 12),
              Text('Edit profile',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF031E2A))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          height: 44,
          child: Row(
            children: const [
              Icon(Icons.delete_outline,
                  color: AppColors.warning, size: 20),
              SizedBox(width: 12),
              Text('Delete profile',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.warning)),
            ],
          ),
        ),
      ],
    );
  }

  void _openEditChild(BuildContext context, _ChildProfile child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      useSafeArea: true,
      builder: (_) => _ChildEditSheet(
        child: child,
        onSave: (name, dob, gender, weight, height) async {
          final w = double.tryParse(weight);
          final h = double.tryParse(height);
          await ChildService().updateChild(
            id: child.id,
            name: name,
            dob: dob,
            gender: gender,
            weightKg: w,
            heightCm: h,
          );
          if (!mounted) return;
          setState(() {
            child.name = name;
            child.dob = dob;
            child.gender = gender;
            child.weightKg = w;
            child.heightCm = h;
            _localOverrides[child.id] = child;
          });
          reload();
        },
      ),
    );
  }

  void _confirmDeleteChild(BuildContext context, _ChildProfile child) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete profile?'),
        content: Text('Remove ${child.name} from your children list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              minimumSize: const Size(88, 44),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await DeviceService().deleteDevice(child.deviceId);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Could not delete profile. Please try again.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Child detail bottom sheet ─────────────────────────────────────────────────

class _ChildDetailSheet extends StatefulWidget {
  const _ChildDetailSheet({required this.child});
  final _ChildProfile child;

  @override
  State<_ChildDetailSheet> createState() => _ChildDetailSheetState();
}

class _ChildDetailSheetState extends State<_ChildDetailSheet> {
  late final Stream<SeatStatus> _liveStream = LiveService().liveStream();

  _ChildProfile _withLive(_ChildProfile base, SeatStatus live) {
    return _ChildProfile(
      id: base.id,
      deviceId: base.deviceId,
      name: base.name,
      dob: base.dob,
      battery: live.battery,
      isWarning: live.severity == SeatSeverity.warning,
      temperature: live.temperature,
      buckled: live.buckled,
      distanceNear: live.distanceNear,
      gender: base.gender,
      weightKg: base.weightKg,
      heightCm: base.heightCm,
      photoPath: base.photoPath,
      hardwareLinked: base.hardwareLinked,
      createdAt: base.createdAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.child.hardwareLinked) {
      final simulated =
          SimulatedStatusService.instance.forChild(widget.child.id);
      return _buildSheet(context, _withLive(widget.child, simulated), simulated);
    }
    return StreamBuilder<SeatStatus>(
      stream: _liveStream,
      builder: (context, snap) {
        final live = snap.data;
        final child = live != null
            ? _withLive(widget.child, live)
            : widget.child;
        return _buildSheet(context, child, live);
      },
    );
  }

  Widget _buildSheet(
    BuildContext context,
    _ChildProfile child,
    SeatStatus? live,
  ) {
    final safe = !child.isWarning;
    final isGirl = child.gender == 'Girl';
    final statusColor =
        safe ? const Color(0xFF56B337) : const Color(0xFFC2291D);
    // Keep gender header colors even when warning — only the SAFE/WARNING
    // chip and TEMP wording turn red for heat.
    final headerTop = isGirl
        ? const Color(0xFFF5B4CD)
        : const Color(0xFF7FD0E4);
    final headerBot = isGirl
        ? const Color(0xFFFCEAF2)
        : const Color(0xFFD7F1F8);
    final avatarBg = isGirl
        ? const Color(0xFFF5B4CD)
        : const Color(0xFF7FD0E4);
    final headerOnColor = AppColors.navy;
    final headerMuted = AppColors.navy.withAlpha(225);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                elevation: 0,
                child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [headerTop, headerBot],
                  ),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: safe
                              ? AppColors.navy.withAlpha(60)
                              : Colors.white54,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        SignedAvatar(
                          photoPath: child.photoPath,
                          radius: 30,
                          backgroundColor: avatarBg,
                          iconColor: AppColors.navy,
                          fallbackIcon: Icons.child_care,
                        ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.name,
                            style: TextStyle(
                                color: headerOnColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text([child.ageLabel, if (child.gender != null && child.gender!.isNotEmpty) child.gender!].join(' · '),
                            style: TextStyle(
                                color: headerMuted, fontSize: 13)),
                        if (child.gender != null ||
                            child.weightKg != null ||
                            child.heightCm != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (child.gender != null && child.gender!.isNotEmpty)
                                child.gender!,
                              if (child.weightKg != null)
                                '${child.weightKg!.toStringAsFixed(1)} kg',
                              if (child.heightCm != null)
                                '${child.heightCm!.toStringAsFixed(0)} cm',
                            ].join(' · '),
                            style: TextStyle(
                                color: headerMuted, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      safe ? 'SAFE' : 'WARNING',
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
              Expanded(
                child: ClipRect(
                  child: ColoredBox(
                    color: Colors.white,
                    child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                children: [
                  const Text('Live Status',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF031E2A))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: _statCard(
                        icon: Icons.thermostat,
                        label: 'Temperature',
                        value: '${child.temperature.toStringAsFixed(0)}°C',
                        sub: child.temperature > kHeatThresholdC
                            ? 'High temperature'
                            : 'Normal range',
                        safe: child.temperature <= kHeatThresholdC,
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard(
                        icon: Icons.link,
                        label: 'Buckle',
                        value: child.buckled ? 'Buckled' : 'Unbuckled',
                        sub: child.buckled ? 'Secured' : 'Not secured',
                        safe: child.buckled,
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _statCard(
                        icon: Icons.location_on,
                        label: 'Distance',
                        value: child.distanceNear ? 'Near' : 'Far',
                        sub: child.distanceNear
                            ? 'Caregiver close'
                            : 'Caregiver away',
                        safe: child.distanceNear,
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard(
                        icon: Icons.battery_full,
                        label: 'Battery',
                        value: '${child.battery}%',
                        sub: child.battery > 20 ? 'Good' : 'Low battery',
                        safe: child.battery > 20,
                      )),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Temperature Analytics',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF031E2A))),
                  const SizedBox(height: 4),
                  const Text('Last 12 hours',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0x8C031E2A))),
                  const SizedBox(height: 12),
                  _neutralCard(
                    padding: EdgeInsets.zero,
                    child: _TempGraph(
                      currentTemp: child.temperature,
                      useHardwareHistory: child.hardwareLinked,
                      historySince: child.createdAt,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Device Info',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF031E2A))),
                  const SizedBox(height: 12),
                  _neutralCard(
                    child: Column(
                      children: [
                        _infoRow(Icons.gps_fixed, 'GPS',
                            live?.gpsLabel ?? 'No GPS fix'),
                        _infoRow(
                          Icons.sensors,
                          'Seat sensor',
                          live?.present == true
                              ? 'Weight detected'
                              : 'Seat empty',
                          padBottom: false,
                        ),
                      ],
                    ),
                  ),
                    const SizedBox(height: 24),
                  ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final _neutralShadow = [
    BoxShadow(
      color: AppColors.hint.withAlpha(70),
      blurRadius: 2,
      offset: const Offset(2, 3),
    ),
  ];

  Widget _neutralCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _neutralShadow,
      ),
      child: child,
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required bool safe,
  }) {
    final bg = !safe ? const Color(0xFFFFE8E8) : AppColors.card;
    final iconColor = !safe ? AppColors.warning : AppColors.accent;
    final valueColor =
        safe ? AppColors.textPrimary : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _neutralShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: valueColor)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF031E2A))),
          Text(sub,
              style: const TextStyle(
                  fontSize: 11, color: Color(0x8C031E2A))),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {bool padBottom = true}) {
    return Padding(
      padding: EdgeInsets.only(bottom: padBottom ? 12 : 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F5FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0x8C031E2A))),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF031E2A)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Temperature graph widget (custom painted) ────────────────────────────────

class _TempGraph extends StatefulWidget {
  const _TempGraph({
    required this.currentTemp,
    this.useHardwareHistory = true,
    this.historySince,
  });

  final double currentTemp;
  final bool useHardwareHistory;
  final DateTime? historySince;

  @override
  State<_TempGraph> createState() => _TempGraphState();
}

class _TempGraphState extends State<_TempGraph> {
  List<TemperatureSample> _samples = const [];
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.useHardwareHistory) {
      if (!mounted) return;
      setState(() => _samples = const []);
      return;
    }
    final rows = await TemperatureHistoryService.instance
        .fetchLast12Hours(since: widget.historySince);
    if (!mounted) return;
    setState(() => _samples = rows);
  }

  @override
  Widget build(BuildContext context) {
    final nowTemp = widget.currentTemp > 0 ? widget.currentTemp : null;
    final buckets =
        TemperatureHistoryService.hourlyBuckets(_samples, DateTime.now());
    final plotData = TemperatureHistoryService.fillBuckets(buckets, nowTemp);
    final dangerLine = kHeatThresholdC;

    var minY = 18.0;
    var maxY = dangerLine + 6;
    for (final v in plotData) {
      if (v - 2 < minY) minY = v - 2;
      if (v + 2 > maxY) maxY = v + 2;
    }

    return SizedBox(
      height: 160,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: plotData.isEmpty
            ? const Center(
                child: Text(
                  'Collecting temperature history…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _TempLinePainter(
                        data: plotData,
                        minY: minY,
                        maxY: maxY,
                        dangerLine: dangerLine,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      7,
                      (i) {
                        final hoursAgo = 12 - i * 2;
                        final label = hoursAgo == 0 ? 'Now' : '-${hoursAgo}h';
                        return Text(label,
                            style: const TextStyle(
                                fontSize: 10, color: Color(0x8C031E2A)));
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TempLinePainter extends CustomPainter {
  final List<double> data;
  final double minY, maxY, dangerLine;
  const _TempLinePainter(
      {required this.data,
      required this.minY,
      required this.maxY,
      required this.dangerLine});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final w = size.width;
    final h = size.height;

    double xOf(int i) =>
        data.length == 1 ? w / 2 : i / (data.length - 1) * w;
    final ySpan = (maxY - minY).abs() < 0.01 ? 1.0 : (maxY - minY);
    double yOf(double v) => h - ((v - minY) / ySpan) * h;

    // ── danger threshold line
    final dangerY = yOf(dangerLine);
    canvas.drawLine(
      Offset(0, dangerY),
      Offset(w, dangerY),
      Paint()
        ..color = AppColors.warning.withValues(alpha: 0.5)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high,
    );
    // label
    final dangerStyle = TextStyle(
        fontSize: 9, color: AppColors.warning, fontWeight: FontWeight.w600);
    final dangerTp = TextPainter(
        text: TextSpan(
            text: '${dangerLine.toStringAsFixed(0)}°C danger',
            style: dangerStyle),
        textDirection: TextDirection.ltr)
      ..layout();
    dangerTp.paint(canvas, Offset(w - dangerTp.width - 4, dangerY - 12));

    // ── filled area
    final fillPath = Path();
    fillPath.moveTo(xOf(0), yOf(data[0]));
    for (int i = 1; i < data.length; i++) {
      final x0 = xOf(i - 1), y0 = yOf(data[i - 1]);
      final x1 = xOf(i), y1 = yOf(data[i]);
      final cx = (x0 + x1) / 2;
      fillPath.cubicTo(cx, y0, cx, y1, x1, y1);
    }
    fillPath.lineTo(xOf(data.length - 1), h);
    fillPath.lineTo(0, h);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accent.withValues(alpha: 0.25),
            AppColors.accent.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h))
        ..style = PaintingStyle.fill,
    );

    // ── line
    final linePath = Path();
    linePath.moveTo(xOf(0), yOf(data[0]));
    for (int i = 1; i < data.length; i++) {
      final x0 = xOf(i - 1), y0 = yOf(data[i - 1]);
      final x1 = xOf(i), y1 = yOf(data[i]);
      final cx = (x0 + x1) / 2;
      linePath.cubicTo(cx, y0, cx, y1, x1, y1);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );

    // ── dots + value labels at start / peak / end
    final highlights = {0, 5, data.length - 1};
    for (int i = 0; i < data.length; i++) {
      final cx = xOf(i);
      final cy = yOf(data[i]);
      if (highlights.contains(i)) {
        canvas.drawCircle(
          Offset(cx, cy),
          4,
          Paint()..color = AppColors.accent,
        );
        canvas.drawCircle(
          Offset(cx, cy),
          2.5,
          Paint()..color = Colors.white,
        );
        final label = '${data[i].toStringAsFixed(1)}°';
        final tp = TextPainter(
            text: TextSpan(
                text: label,
                style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600)),
            textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(canvas,
            Offset(cx - tp.width / 2, cy - tp.height - 5));
      }
    }

    // ── Y-axis labels
    final step = (maxY - minY) <= 12 ? 4.0 : 6.0;
    var tick = (minY / step).ceil() * step;
    while (tick <= maxY) {
      final ty = yOf(tick);
      if (ty >= 0 && ty <= h) {
        final tp = TextPainter(
            text: TextSpan(
                text: '${tick.toInt()}°',
                style: const TextStyle(
                    fontSize: 9, color: Color(0x8C031E2A))),
            textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(canvas, Offset(0, ty - tp.height / 2));
        canvas.drawLine(
          Offset(tp.width + 2, ty),
          Offset(w, ty),
          Paint()
            ..color = const Color(0x18031E2A)
            ..strokeWidth = 0.5,
        );
      }
      tick += step;
    }
  }

  @override
  bool shouldRepaint(covariant _TempLinePainter old) =>
      old.data != data ||
      old.minY != minY ||
      old.maxY != maxY ||
      old.dangerLine != dangerLine;
}

// ── Child edit profile bottom sheet ─────────────────────────────────────────

class _ChildEditSheet extends StatefulWidget {
  final _ChildProfile child;
  final Future<void> Function(
    String name,
    DateTime dob,
    String gender,
    String weight,
    String height,
  ) onSave;

  const _ChildEditSheet({required this.child, required this.onSave});

  @override
  State<_ChildEditSheet> createState() => _ChildEditSheetState();
}

class _ChildEditSheetState extends State<_ChildEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late DateTime _selectedDob;
  late String _gender;
  bool _saving = false;
  String? _photoPath;
  File? _photoPreview;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.child.name);
    _weightCtrl = TextEditingController(
      text: widget.child.weightKg?.toStringAsFixed(1) ?? '',
    );
    _heightCtrl = TextEditingController(
      text: widget.child.heightCm?.toStringAsFixed(0) ?? '',
    );
    _selectedDob = widget.child.dob;
    _gender = widget.child.gender ?? kGenderOptions.first;
    _photoPath = widget.child.photoPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickChildPhoto() async {
    final action = await showModalBottomSheet<String>(
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
            if (_photoPath != null)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.warning),
                title: const Text('Remove Photo',
                    style: TextStyle(color: AppColors.warning)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;

    if (action == 'remove') {
      final oldPath = _photoPath;
      await ChildService().updateChildPhoto(widget.child.id, null);
      if (oldPath != null) SignedAvatar.invalidate(oldPath);
      if (!mounted) return;
      setState(() {
        _photoPath = null;
        _photoPreview = null;
      });
      return;
    }

    final familyId = await FamilyService().myFamilyId();
    if (familyId == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    final result = await ImageUploadService().pickCropAndUpload(
      source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
      familyId: familyId,
      entityType: 'children',
      entityId: widget.child.id,
    );
    if (result != null) {
      await ChildService().updateChildPhoto(widget.child.id, result.path);
      SignedAvatar.invalidate(result.path);
    }
    if (!mounted) return;
    setState(() {
      _uploadingPhoto = false;
      if (result != null) {
        _photoPath = result.path;
        _photoPreview = result.localFile;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob,
      firstDate: DateTime(now.year - 12, now.month, 1),
      lastDate: DateTime(now.year, now.month - 1, now.day),
      helpText: 'Select date of birth',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.navy,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDob = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _nameCtrl.text.trim(),
        _selectedDob,
        _gender,
        _weightCtrl.text.trim(),
        _heightCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      // Parent shows error snackbar.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.5,
      maxChildSize: 0.85,
      builder: (_, scrollCtrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          color: const Color(0xFFF4F6F9),
          child: Column(
            children: [
              // ── Gradient header with drag handle + title + avatar ──────
              _ChildEditHeader(
                name: widget.child.name,
                photoPath: _photoPath,
                photoPreview: _photoPreview,
                uploading: _uploadingPhoto,
                onTap: _uploadingPhoto ? null : _pickChildPhoto,
                onClose: () => Navigator.of(context).pop(),
              ),
              // ── Scrollable form ────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _section([
                          _formRow(
                            label: 'Child Name',
                            icon: Icons.person_outline,
                            controller: _nameCtrl,
                            hint: 'e.g. Jason Tan',
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Name is required'
                                    : null,
                          ),
                          _sep(),
                          // Date of birth picker row
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFD4EEF8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.cake_outlined,
                                        color: AppColors.accent, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Date of Birth',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_selectedDob.day.toString().padLeft(2, '0')} '
                                          '${_monthName(_selectedDob.month)} '
                                          '${_selectedDob.year}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Computed age badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4EEF8),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _ageFromDob(_selectedDob),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accent),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right,
                                      color: AppColors.textSecondary, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        _section([
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: GenderSelector(
                              value: _gender,
                              onChanged: (value) => setState(() => _gender = value),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        _section([
                          _formRow(
                            label: 'Weight (kg)',
                            icon: Icons.monitor_weight_outlined,
                            controller: _weightCtrl,
                            hint: 'e.g. 8.5',
                            keyboard: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final val = double.tryParse(v);
                              if (val == null) return 'Enter a valid number';
                              if (val <= 0 || val > 60) {
                                return 'Enter a weight up to 60 kg';
                              }
                              return null;
                            },
                          ),
                          _sep(),
                          _formRow(
                            label: 'Height (cm)',
                            icon: Icons.straighten_outlined,
                            controller: _heightCtrl,
                            hint: 'e.g. 73',
                            keyboard: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final val = double.tryParse(v);
                              if (val == null) return 'Enter a valid number';
                              if (val < 24 || val > 200) {
                                return 'Enter a height from 24 to 200 cm';
                              }
                              return null;
                            },
                          ),
                        ]),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _submit,
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
                                        strokeWidth: 2,
                                        color: Colors.white))
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
        ),
      ),
    );
  }

  static String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  Widget _section(List<Widget> rows) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: rows),
      );

  Widget _sep() => const Divider(
      height: 1, thickness: 1, color: Colors.black12,
      indent: 60, endIndent: 16);

  Widget _formRow({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        width: 1),
                  ),
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  labelStyle: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Child edit header ─────────────────────────────────────────────────────────

class _ChildEditHeader extends StatelessWidget {
  final String name;
  final String? photoPath;
  final File? photoPreview;
  final bool uploading;
  final VoidCallback? onTap;
  final VoidCallback onClose;

  const _ChildEditHeader({
    required this.name,
    this.photoPath,
    this.photoPreview,
    this.uploading = false,
    this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Drag handle
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Gradient wave
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipPath(
              clipper: _WaveClipper(),
              child: Container(
                height: 130,
                decoration: const BoxDecoration(gradient: kHeaderGradient),
              ),
            ),
          ),
          // Close + title
          Positioned(
            top: 22, left: 0, right: 0,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 22),
                  onPressed: onClose,
                ),
                Text(
                  'Edit — $name',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          // Avatar overlapping wave bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onTap,
                child: Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
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
                      child: ClipOval(
                        child: uploading
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : photoPreview != null
                                ? Image.file(
                                    photoPreview!,
                                    fit: BoxFit.cover,
                                    width: 72,
                                    height: 72,
                                  )
                                : SignedAvatar(
                                    photoPath: photoPath,
                                    radius: 36,
                                    backgroundColor: const Color(0xFFD4EEF8),
                                    fallbackIcon: Icons.child_care,
                                    iconColor: AppColors.accent,
                                  ),
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final h = size.height;
    final w = size.width;
    path.lineTo(0, h - 10);
    path.cubicTo(w * 0.12, h - 10, w * 0.20, h - 22, w * 0.32, h - 18);
    path.cubicTo(w * 0.40, h - 14, w * 0.47, h - 8, w * 0.54, h - 10);
    path.cubicTo(w * 0.61, h - 12, w * 0.70, h - 26, w * 0.82, h - 22);
    path.cubicTo(w * 0.90, h - 18, w * 0.96, h - 12, w, h - 12);
    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
