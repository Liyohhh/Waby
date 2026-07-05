import 'dart:math' show pi;
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/child.dart';
import '../models/seat_status.dart';
import '../services/auth_service.dart';
import '../services/child_service.dart';
import '../services/device_service.dart';
import '../services/live_service.dart';
import '../widgets/status_pill.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

/// Waby home dashboard, wired to live Supabase data from the `live` table.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LiveService _liveService = LiveService();
  late final Stream<SeatStatus> _liveStream = _liveService.liveStream();

  final ChildService _childService = ChildService();
  late final Stream<List<Child>> _childrenStream =
      _childService.myChildrenStream();

  _CardStatus _mapSeverity(SeatSeverity s) => switch (s) {
        SeatSeverity.safe => _CardStatus.safe,
        SeatSeverity.caution => _CardStatus.caution,
        SeatSeverity.warning => _CardStatus.warning,
      };

  String _formatDob(DateTime? d) {
    if (d == null) return '';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return 'DOB: ${d.day} ${m[d.month - 1]} ${d.year}';
  }

  String _formatDetails(double? w, double? h) {
    final parts = <String>[];
    if (w != null) parts.add('${w.toStringAsFixed(1)} kg');
    if (h != null) parts.add('${h.toStringAsFixed(0)} cm');
    return parts.join(' · ');
  }

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
        child: Column(
          children: [
            Icon(Icons.event_seat, size: 72, color: AppColors.accent.withAlpha(120)),
            const SizedBox(height: 16),
            const Text('No device yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Add your Waby seat to start monitoring your baby.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<List<Child>>(
        stream: _childrenStream,
        builder: (context, childSnap) {
          final children = childSnap.data ?? const <Child>[];
          return StreamBuilder<SeatStatus>(
            stream: _liveStream,
            builder: (context, liveSnap) {
              final status = liveSnap.data ?? SeatStatus.empty();
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(context, status),
                    const SizedBox(height: 16),
                    _sounds(),
                    const SizedBox(height: 16),
                    if (children.isEmpty)
                      _emptyState()
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            for (final c in children) ...[
                              _ChildCard(
                                name: c.name,
                                dob: _formatDob(c.dob),
                                details:
                                    _formatDetails(c.weightKg, c.heightCm),
                                status: _mapSeverity(status.severity),
                                present: status.present,
                                buckled: status.buckled,
                                near: status.distanceNear,
                                battery: status.battery,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Builder(
                          builder: (ctx) => ElevatedButton(
                            onPressed: () => _showAddDeviceSheet(ctx),
                            child: const Text('Add Device'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 110),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (r) => false,
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, SeatStatus status) {
    // Outer Stack: bg → wave → car (on top of wave) → text
    return Stack(
      children: [
        // ── 1. Light blue background ────────────────────────────────────────
        Positioned.fill(child: Container(color: const Color(0xFFE5FCFF).withAlpha(180))),

        // ── 2. Wave gradient (behind the car) ───────────────────────────────
              ClipPath(
                clipper: _WaveClipper(),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: const BoxDecoration(gradient: kHeaderGradient),
                ),
              ),

        // ── 3. Car image — ON TOP of wave, beside temperature content ────────
        //    left+right pins the car to the right half; Center handles
        //    horizontal centering regardless of image aspect ratio.
        Positioned(
          left: 210,
          right: -15,
          top: 95,
          bottom: 0,
          child: Center(
              child: RotatedBox(
              quarterTurns: 1, // +90° → front of car faces up
              child: Image.asset(
                'assets/images/car_pic_on_top.png',
                height: 85, // controls visual width after rotation
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const SizedBox(),
              ),
            ),
          ),
        ),

        // ── 4. Profile row (always on top) ──────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  child: const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: AppColors.accent, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hi, Mom!',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                      Text('Welcome back!',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _confirmSignOut(context),
                  child: const Icon(Icons.logout, color: Colors.white, size: 26),
                ),
              ],
            ),
          ),
        ),

        // ── 5. Temperature section (below the wave, left side only) ─────────
        Padding(
          padding: const EdgeInsets.only(top: 140),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Left half only — the car occupies the right portion
                final leftWidth = constraints.maxWidth * 0.55;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.thermostat,
                            color: Color(0xFF0063BA), size: 64),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('${status.temperature.toStringAsFixed(0)}°C',
                                style: const TextStyle(
                                    color: Color(0xFF0063BA),
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800)),
                            const Text("Mom's car",
                                style: TextStyle(
                                    color: Color(0xFF031E2A), fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: leftWidth,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ((status.temperature - 20) / (32 - 20))
                              .clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.black12,
                          color: const Color(0xFF088BEA),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: leftWidth,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('20°C',
                              style: TextStyle(
                                  color: Color(0xFF031E2A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          Text('32°C',
                              style: TextStyle(
                                  color: Color(0xFF031E2A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _sounds() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Favourite Sounds',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _soundChip(Icons.play_arrow, 'Rainyday'),
              const SizedBox(width: 10),
              _soundChip(Icons.play_arrow, 'Dreamy'),
              const SizedBox(width: 10),
              _soundChip(Icons.play_arrow, 'Ocean'),
              const SizedBox(width: 10),
              _soundChip(Icons.play_arrow, 'Lullaby'),
              const SizedBox(width: 10),
              _soundChip(Icons.add, 'Add sound'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _soundChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF018FB4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Card status enum ──────────────────────────────────────────────────────────

enum _CardStatus { safe, caution, warning }

// ── Add Device sheet ──────────────────────────────────────────────────────────

Future<void> _showAddDeviceSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddDeviceSheet(),
  );
}

class _AddDeviceSheet extends StatefulWidget {
  const _AddDeviceSheet();

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  int _step = 0;
  bool _connecting = false;
  bool _saving = false;
  String? _error;

  final _name = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  DateTime? _dob;

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() { _connecting = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() { _connecting = false; _step = 1; });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? now,
      firstDate: DateTime(now.year - 6),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String _formatDob(DateTime? d) {
    if (d == null) return 'Select date';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = "Please enter the child's name.");
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await DeviceService().addDeviceWithChild(
        deviceName: 'Waby Seat',
        childName: _name.text.trim(),
        dob: _dob,
        weightKg: double.tryParse(_weight.text),
        heightCm: double.tryParse(_height.text),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not add device. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_step == 0) ...[
              const Text(
                'Add Device',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap Connect to link your Waby seat.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: _connecting
                    ? const SizedBox(
                        height: 64,
                        width: 64,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.accent,
                        ),
                      )
                    : const Icon(
                        Icons.wifi_tethering,
                        size: 64,
                        color: AppColors.accent,
                      ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _connecting ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Connect',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'Add your child',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Child name',
                  filled: true,
                  fillColor: AppColors.field,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _saving ? null : _pickDob,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.field,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date of birth',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDob(_dob),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _dob == null
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _weight,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Weight (kg)',
                  filled: true,
                  fillColor: AppColors.field,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _height,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Height (cm)',
                  filled: true,
                  fillColor: AppColors.field,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.warning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Child status card ─────────────────────────────────────────────────────────

class _ChildCard extends StatelessWidget {
  final String name;
  final String dob;
  final String details; // single line: "8.5 kg · 73 cm"
  final _CardStatus status;
  final bool present;
  final bool buckled;
  final bool near;
  final int battery;

  const _ChildCard({
    required this.name,
    required this.dob,
    required this.details,
    required this.status,
    this.present = true,
    required this.buckled,
    required this.near,
    required this.battery,
  });

  // Safe & caution share the calm blue background; warning gets red.
  // An empty seat is always calm — never show the warning red.
  Color get _cardBg {
    if (!present) return AppColors.safeCard;
    return switch (status) {
      _CardStatus.safe    => AppColors.safeCard,
      _CardStatus.caution => AppColors.safeCard,
      _CardStatus.warning => AppColors.warningCard,
    };
  }

  Color get _badgeColor => switch (status) {
        _CardStatus.safe    => AppColors.safe,               // green
        _CardStatus.caution => const Color(0xFFE6A817),      // yellow/amber
        _CardStatus.warning => AppColors.warning,            // red
      };

  String get _badgeLabel => switch (status) {
        _CardStatus.safe    => 'SAFE',
        _CardStatus.caution => 'CAUTION',
        _CardStatus.warning => 'WARNING',
      };

  // Per-indicator tones — each pill colours itself independently.
  StatusTone get _buckleTone  => buckled      ? StatusTone.good : StatusTone.bad;
  StatusTone get _nearTone    => near         ? StatusTone.good : StatusTone.bad;
  StatusTone get _batteryTone => battery > 20 ? StatusTone.neutral : StatusTone.bad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.accent,
                child: Text(name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(dob,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4)),
                    Text(details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: present
                      ? _badgeColor
                      : AppColors.textSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(present ? _badgeLabel : 'SEAT EMPTY',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!present)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.child_care_outlined,
                    size: 18, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Text('No baby detected',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: StatusPill(
                  icon: buckled ? Icons.link : Icons.link_off,
                  label: buckled ? 'Latched' : 'Unlatched',
                  tone: _buckleTone,
                )),
                const SizedBox(width: 8),
                Expanded(child: StatusPill(
                  icon: near ? Icons.location_on : Icons.location_off,
                  label: near ? 'Near' : 'Far',
                  tone: _nearTone,
                )),
                const SizedBox(width: 8),
                Expanded(child: StatusPill(
                  icon: battery <= 20 ? Icons.battery_alert : Icons.battery_full,
                  label: '$battery%',
                  tone: _batteryTone,
                )),
              ],
            ),
        ],
      ),
    );
  }
}

/// Two-loop wave: small crest on the left, bigger crest on the right.
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final h = size.height;
    final w = size.width;

    path.lineTo(0, h - 10);

    // ── Left crest — flat, subtle bump ────────────────────────────────────
    path.cubicTo(
      w * 0.12, h - 10,
      w * 0.20, h - 22,
      w * 0.32, h - 18,
    );
    // Trough
    path.cubicTo(
      w * 0.40, h - 14,
      w * 0.47, h - 8,
      w * 0.54, h - 10,
    );

    // ── Right crest — gentle, flattened bump ──────────────────────────────
    path.cubicTo(
      w * 0.61, h - 12,
      w * 0.70, h - 26,
      w * 0.82, h - 22,
    );
    // Settle to right edge
    path.cubicTo(
      w * 0.90, h - 18,
      w * 0.96, h - 12,
      w, h - 12,
    );

    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}