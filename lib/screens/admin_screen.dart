import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Admin dashboard — shows all monitored users and their live seat data.
/// Data is mocked for demo; wire to Supabase in production.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  // ── Mock data ─────────────────────────────────────────────────────────────

  static const _users = [
    _UserData(
      name: 'Mom — Sarah Tan',
      email: 'sarah@example.com',
      role: 'Parent',
      children: [
        _ChildData(name: 'Jason Tan',   tempC: 23, buckled: true,  near: true,  battery: 88, status: _SeatStatus.safe),
        _ChildData(name: 'Nur Alysha', tempC: 29, buckled: false, near: false, battery: 15, status: _SeatStatus.warning),
      ],
    ),
    _UserData(
      name: 'Dad — Ahmad Razif',
      email: 'ahmad@example.com',
      role: 'Parent',
      children: [
        _ChildData(name: 'Rayyan',  tempC: 24, buckled: true,  near: true,  battery: 72, status: _SeatStatus.safe),
      ],
    ),
    _UserData(
      name: 'Grandma — Lily Lim',
      email: 'lily@example.com',
      role: 'Guardian',
      children: [
        _ChildData(name: 'Mia Lim', tempC: 31, buckled: true,  near: false, battery: 42, status: _SeatStatus.heat),
      ],
    ),
  ];

  // ── Design constants ──────────────────────────────────────────────────────

  static const _kGutter     = 20.0;
  static const _kCardRadius = 12.0;
  static const _kSectionGap = 20.0;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalUsers    = _users.length;
    final totalChildren = _users.fold(0, (s, u) => s + u.children.length);
    final totalAlerts   = _users.fold(
      0, (s, u) => s + u.children.where((c) => c.status != _SeatStatus.safe).length);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: _kSectionGap),

            // ── Summary stats ─────────────────────────────────────────────
            _buildStats(
              totalUsers: totalUsers,
              totalChildren: totalChildren,
              totalAlerts: totalAlerts,
            ),
            const SizedBox(height: _kSectionGap),

            // ── User cards ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kGutter),
              child: Row(
                children: const [
                  Text('Monitored Users',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...(_users.map((u) => Padding(
              padding: const EdgeInsets.fromLTRB(
                  _kGutter, 0, _kGutter, 12),
              child: _buildUserCard(u),
            ))),

            // ── Recent alerts ─────────────────────────────────────────────
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kGutter),
              child: const Text('Recent Alerts',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 12),
            _buildAlerts(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Admin Panel',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Monitor all users & seat data',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withAlpha(100)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.admin_panel_settings,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('ADMIN',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Summary stats ─────────────────────────────────────────────────────────

  Widget _buildStats({
    required int totalUsers,
    required int totalChildren,
    required int totalAlerts,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kGutter),
      child: Row(
        children: [
          _statCard('Users',    '$totalUsers',    Icons.people,         AppColors.accent),
          const SizedBox(width: 10),
          _statCard('Seats',    '$totalChildren', Icons.child_care,     AppColors.dot),
          const SizedBox(width: 10),
          _statCard('Alerts',   '$totalAlerts',   Icons.warning_amber,  totalAlerts > 0 ? AppColors.warning : AppColors.safe),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kCardRadius),
          boxShadow: const [
            BoxShadow(
                color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── User card ─────────────────────────────────────────────────────────────

  Widget _buildUserCard(_UserData user) {
    final hasAlert = user.children.any((c) => c.status != _SeatStatus.safe);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: hasAlert
            ? Border.all(color: AppColors.warning.withAlpha(80), width: 1.5)
            : null,
        boxShadow: const [
          BoxShadow(
              color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User header row
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFD4EEF8),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0] : '?',
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      Text(user.email,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(user.role,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5EAF0)),

          // Children seats
          ...user.children.map((child) => _buildSeatRow(child)),
        ],
      ),
    );
  }

  // ── Seat row (inside user card) ───────────────────────────────────────────

  Widget _buildSeatRow(_ChildData child) {
    final statusColor = child.status == _SeatStatus.safe
        ? AppColors.safe
        : AppColors.warning;
    final statusLabel = switch (child.status) {
      _SeatStatus.safe    => 'SAFE',
      _SeatStatus.warning => 'WARNING',
      _SeatStatus.heat    => 'HEAT',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          // Child name + seat pills
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _miniPill(Icons.thermostat,
                        '${child.tempC}°C',
                        child.tempC >= 30
                            ? AppColors.warning
                            : AppColors.dot),
                    const SizedBox(width: 6),
                    _miniPill(
                        child.buckled ? Icons.link : Icons.link_off,
                        child.buckled ? 'Buckled' : 'Unbuckled',
                        child.buckled ? AppColors.safe : AppColors.warning),
                    const SizedBox(width: 6),
                    _miniPill(Icons.location_on,
                        child.near ? 'Near' : 'Far',
                        child.near ? AppColors.accent : AppColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Status badge + battery
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 10)),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.battery_full,
                      size: 13,
                      color: child.battery <= 20
                          ? AppColors.warning
                          : AppColors.textSecondary),
                  Text('${child.battery}%',
                      style: TextStyle(
                          fontSize: 11,
                          color: child.battery <= 20
                              ? AppColors.warning
                              : AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }

  // ── Recent alerts ─────────────────────────────────────────────────────────

  Widget _buildAlerts() {
    final alerts = [
      _AlertItem(
          time: '2:14 PM',
          user: 'Sarah Tan',
          message: 'Nur Alysha — seat unbuckled while caregiver is far'),
      _AlertItem(
          time: '1:47 PM',
          user: 'Lily Lim',
          message: 'Mia Lim — seat temperature exceeded 30 °C'),
      _AlertItem(
          time: '11:32 AM',
          user: 'Ahmad Razif',
          message: 'Rayyan — left-behind alert triggered'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kGutter),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kCardRadius),
          boxShadow: const [
            BoxShadow(
                color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: List.generate(alerts.length, (i) {
            final a = alerts[i];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.warning_amber,
                            size: 18, color: AppColors.warning),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(a.user,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary)),
                                const Spacer(),
                                Text(a.time,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(a.message,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < alerts.length - 1)
                  const Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 64,
                      color: Color(0xFFE5EAF0)),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ── Data models (local / mock) ────────────────────────────────────────────

enum _SeatStatus { safe, warning, heat }

class _UserData {
  final String name;
  final String email;
  final String role;
  final List<_ChildData> children;
  const _UserData({
    required this.name,
    required this.email,
    required this.role,
    required this.children,
  });
}

class _ChildData {
  final String name;
  final int tempC;
  final bool buckled;
  final bool near;
  final int battery;
  final _SeatStatus status;
  const _ChildData({
    required this.name,
    required this.tempC,
    required this.buckled,
    required this.near,
    required this.battery,
    required this.status,
  });
}

class _AlertItem {
  final String time;
  final String user;
  final String message;
  const _AlertItem({
    required this.time,
    required this.user,
    required this.message,
  });
}

// ── Wave clipper ──────────────────────────────────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final h = size.height;
    final w = size.width;
    return Path()
      ..lineTo(0, h - 10)
      ..cubicTo(w * 0.12, h - 10, w * 0.20, h - 22, w * 0.32, h - 18)
      ..cubicTo(w * 0.40, h - 14, w * 0.47, h - 8,  w * 0.54, h - 10)
      ..cubicTo(w * 0.61, h - 12, w * 0.70, h - 26, w * 0.82, h - 22)
      ..cubicTo(w * 0.90, h - 18, w * 0.96, h - 12, w,        h - 12)
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
