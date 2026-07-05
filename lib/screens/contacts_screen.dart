import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../models/contact.dart';
import '../services/contact_service.dart';

class ContactsScreen extends StatelessWidget {
  ContactsScreen({super.key, this.showBack = true});

  final bool showBack;
  final ContactService _service = ContactService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildChildrenSection(context),
            const SizedBox(height: 20),
            _buildFamilyMembersSection(context),
            const SizedBox(height: 20),
            _buildJoinCodeCard(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                if (showBack)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                const Text('Family',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChildrenSection(BuildContext context) {
    return const _ChildrenSection();
  }

  // ── Family Members section — read-only, managed in Settings ───────────────

  Widget _buildFamilyMembersSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Family Members',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF031E2A))),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'To add or remove members, go to Settings → Family Management.',
            style: TextStyle(fontSize: 11, color: Color(0x8C031E2A)),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Contact>>(
            stream: _service.contactsStream().timeout(
              const Duration(seconds: 6),
              onTimeout: (sink) => sink.add([]),
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('Could not load contacts.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12)),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final contacts = snapshot.data ?? [];
              if (contacts.isEmpty) {
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
              return Column(
                children: List.generate(contacts.length, (i) {
                  final c = contacts[i];
                  return Column(
                    children: [
                      _memberRow(c, verified: i == 0),
                      if (i < contacts.length - 1)
                        const Divider(
                            color: Colors.black12, height: 1, thickness: 1),
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

  Widget _memberRow(Contact c, {bool verified = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.accent,
            child: Text(
              c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
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
                Row(
                  children: [
                    Text(c.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF031E2A))),
                    if (verified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified,
                          size: 14, color: Color(0xFF008FB4)),
                    ],
                  ],
                ),
                Text(c.relation,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0x80031E2A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Family Join Code card ─────────────────────────────────────────────────

  Widget _buildJoinCodeCard() {
    const code = 'BT - 8942';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE9F5FE),
          border: Border.all(
              color: const Color(0xFF1F61B2).withAlpha(80),
              style: BorderStyle.solid,
              width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFBDD6F3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt,
                  color: Color(0xFF1F61B2), size: 20),
            ),
            const SizedBox(height: 8),
            const Text('Family Join Code',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF031E2A))),
            const SizedBox(height: 4),
            const Text('Share this code to add new family members',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, color: Color(0x8C031E2A))),
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(code,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3D7FB0))),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Clipboard.setData(
                          const ClipboardData(text: code)),
                      child: const Icon(Icons.copy,
                          size: 18, color: Color(0xFF3D7FB0)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Children section (unchanged) ──────────────────────────────────────────────

class _ChildProfile {
  _ChildProfile({
    required this.id,
    required this.name,
    required this.ageLabel,
    required this.battery,
    required this.isWarning,
  });

  final String id;
  String name;
  String ageLabel;
  int battery;
  bool isWarning;
}

class _ChildrenSection extends StatefulWidget {
  const _ChildrenSection();

  @override
  State<_ChildrenSection> createState() => _ChildrenSectionState();
}

class _ChildrenSectionState extends State<_ChildrenSection> {
  final List<_ChildProfile> _children = [
    _ChildProfile(
      id: '1',
      name: 'Jason Tan',
      ageLabel: '2 year',
      battery: 88,
      isWarning: false,
    ),
    _ChildProfile(
      id: '2',
      name: 'Nur Alysha',
      ageLabel: '8 Month',
      battery: 15,
      isWarning: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Children',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF031E2A))),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF6391C9)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Manage',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F61B2))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_children.length, (i) {
            final child = _children[i];
            return Padding(
              padding: EdgeInsets.only(
                  bottom: i < _children.length - 1 ? 8 : 0),
              child: _childCard(context, child),
            );
          }),
        ],
      ),
    );
  }

  Widget _childCard(BuildContext context, _ChildProfile child) {
    final bgColor = child.isWarning
        ? const Color(0xFFFFE5E5)
        : const Color(0xFFDEE8F3);
    final batteryColor = child.isWarning
        ? const Color(0xFFFF0E0E)
        : const Color(0xFF031E2A);

    return GestureDetector(
      onTap: () => _showChildDetail(context, child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accent.withAlpha(180),
              child: const Icon(Icons.child_care,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF031E2A))),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF031E2A)),
                      children: [
                        TextSpan(text: '${child.ageLabel} | '),
                        TextSpan(
                          text: 'Battery: ${child.battery}%',
                          style: TextStyle(color: batteryColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
      icon: const Icon(Icons.more_vert,
          color: Color(0xFF031E2A), size: 20),
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
    final nameCtrl = TextEditingController(text: child.name);
    final ageCtrl = TextEditingController(text: child.ageLabel);
    final batteryCtrl =
        TextEditingController(text: child.battery.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ageCtrl,
              decoration:
                  const InputDecoration(hintText: 'Age (e.g. 2 year)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: batteryCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Battery %'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(88, 44)),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final age = ageCtrl.text.trim();
              final battery = int.tryParse(batteryCtrl.text.trim());
              if (name.isEmpty || age.isEmpty || battery == null) return;
              setState(() {
                child.name = name;
                child.ageLabel = age;
                child.battery = battery.clamp(0, 100);
                child.isWarning = child.battery <= 20;
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
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
            onPressed: () {
              setState(
                  () => _children.removeWhere((c) => c.id == child.id));
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Child detail bottom sheet (unchanged) ─────────────────────────────────────

class _ChildDetailSheet extends StatelessWidget {
  const _ChildDetailSheet({required this.child});
  final _ChildProfile child;

  @override
  Widget build(BuildContext context) {
    final safe = !child.isWarning;
    final statusColor =
        safe ? const Color(0xFF56B337) : const Color(0xFFC2291D);
    final headerTop =
        safe ? const Color(0xFF008FB4) : const Color(0xFFC2291D);
    final headerBot =
        safe ? const Color(0xFF7AD0E4) : const Color(0xFFE05555);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [headerTop, headerBot],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withAlpha(60),
                    child: const Icon(Icons.child_care,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(child.ageLabel,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
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
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(24),
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
                        value: '23°C',
                        sub: 'Normal range',
                        safe: true,
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard(
                        icon: Icons.link,
                        label: 'Buckle',
                        value: safe ? 'Latched' : 'Unlatched',
                        sub: safe ? 'Secured' : 'Not secured',
                        safe: safe,
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
                        value: safe ? 'Near' : 'Far',
                        sub: safe ? 'Caregiver close' : 'Caregiver away',
                        safe: safe,
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
                  const Text('Device Info',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF031E2A))),
                  const SizedBox(height: 12),
                  _infoRow(Icons.bluetooth, 'Connection',
                      'Connected via WiFi'),
                  _infoRow(Icons.gps_fixed, 'GPS',
                      '3.1478° N, 101.6953° E'),
                  _infoRow(
                      Icons.sensors, 'Seat sensor', 'Weight detected'),
                  const SizedBox(height: 24),
                  if (!safe)
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC2291D),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Acknowledge Alert'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required bool safe,
  }) {
    final bg =
        safe ? const Color(0xFFE0EEF9) : const Color(0xFFFFE8E8);
    final iconColor =
        safe ? const Color(0xFF1F61B2) : const Color(0xFFC2291D);
    final valueColor =
        safe ? const Color(0xFF031E2A) : const Color(0xFFC2291D);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
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
                  fontSize: 11, color: Color(0x8C031E2A))),
          Text(sub,
              style: const TextStyle(
                  fontSize: 11, color: Color(0x8C031E2A))),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F5FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(icon, color: const Color(0xFF1F61B2), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0x8C031E2A))),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF031E2A))),
        ],
      ),
    );
  }
}

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
