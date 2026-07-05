import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../widgets/status_pill.dart';
import 'profile_screen.dart';

/// Waby home dashboard. Uses static/mock values for now — temperature and the
/// children will be wired to live Firebase data (seatcare/live) in the next step.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: 16),
            _sounds(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: const [
                  _ChildCard(
                    name: 'Jason Tan',
                    dob: 'DOB: 15 Jan 2026',
                    details: '8.5 kg · 73 cm',
                    status: _CardStatus.safe,
                    buckled: true,
                    near: true,
                    battery: 88,
                  ),
                  SizedBox(height: 16),
                  _ChildCard(
                    name: 'Baby Ali',
                    dob: 'DOB: 10 Jun 2025',
                    details: '6.8 kg · 65 cm',
                    status: _CardStatus.caution,
                    buckled: true,
                    near: true,
                    battery: 11,
                  ),
                  SizedBox(height: 16),
                  _ChildCard(
                    name: 'Nur Alysha',
                    dob: 'DOB: 20 Mar 2025',
                    details: '7.2 kg · 68 cm',
                    status: _CardStatus.warning,
                    buckled: false,
                    near: false,
                    battery: 15,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => _showAddDeviceSheet(ctx),
                  child: const Text('Add Device'),
                ),
              ),
            ),
            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
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
                const Icon(Icons.home_filled, color: Colors.white, size: 28),
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
                      children: const [
                        Icon(Icons.thermostat, color: Color(0xFF0063BA), size: 64),
                        SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('23°C',
                                style: TextStyle(
                                    color: Color(0xFF0063BA),
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800)),
                            Text("Mom's car",
                                style: TextStyle(color: Color(0xFF031E2A), fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: leftWidth,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: const LinearProgressIndicator(
                          value: 0.35,
                          minHeight: 6,
                          backgroundColor: Colors.black12,
                          color: Color(0xFF088BEA),
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

// ── BLE Add-Device sheet ──────────────────────────────────────────────────────

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
  static const _channel = MethodChannel('waby/bluetooth');
  bool _scanning = false;
  String? _connectedName;
  String? _error;

  Future<void> _scan() async {
    setState(() { _scanning = true; _error = null; _connectedName = null; });
    try {
      final name = await _channel.invokeMethod<String>('showDevicePicker');
      if (!mounted) return;
      setState(() { _scanning = false; _connectedName = name; });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        if (e.code != 'CANCELLED') _error = e.message ?? 'Scan failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Add Device',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                  color: AppColors.navy)),
          const SizedBox(height: 6),
          const Text('Tap Scan to find nearby Waby seat devices.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 28),

          // Status icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _connectedName != null
                ? const Icon(Icons.check_circle, size: 64,
                    color: Color(0xFF56B337), key: ValueKey('ok'))
                : Icon(
                    _scanning ? Icons.bluetooth_searching : Icons.bluetooth,
                    size: 64, color: AppColors.accent,
                    key: ValueKey(_scanning.toString())),
          ),
          const SizedBox(height: 16),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _connectedName != null
                  ? 'Paired with $_connectedName'
                  : _scanning ? 'Opening device picker…' : 'No device paired yet',
              key: ValueKey(_connectedName ?? _scanning.toString()),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _connectedName != null
                      ? const Color(0xFF56B337)
                      : AppColors.textSecondary),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.warning))),
              ]),
            ),
          ],

          const SizedBox(height: 28),

          if (!_scanning && _connectedName == null)
            ElevatedButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Scan for Devices'),
            )
          else if (_scanning)
            const SizedBox(
              height: 36, width: 36,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: AppColors.accent),
            )
          else
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
        ],
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
  final bool buckled;
  final bool near;
  final int battery;

  const _ChildCard({
    required this.name,
    required this.dob,
    required this.details,
    required this.status,
    required this.buckled,
    required this.near,
    required this.battery,
  });

  // All cards share the same calm blue background.
  Color get _cardBg => AppColors.safeCard;

  Color get _badgeColor => switch (status) {
        _CardStatus.safe    => AppColors.safe,    // green — all good
        _CardStatus.caution => AppColors.accent,  // blue  — attention, no alarm
        _CardStatus.warning => AppColors.warning, // red   — triggers escalation
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
                  color: _badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_badgeLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
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