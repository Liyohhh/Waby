import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/seat_status.dart';
import '../services/alert_service.dart';

class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key, required this.event, this.childName});
  final AlertEvent event;
  final String? childName;

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  Timer? _ticker;
  int _tier = 1;
  Duration _remaining = Duration.zero;
  bool _telegramSent = false;

  bool get _isCritical =>
      widget.event.reason == AlertReason.leftBehind ||
      widget.event.reason == AlertReason.heat;

  @override
  void initState() {
    super.initState();
    if (_isCritical) {
      _syncFromService();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(_syncFromService);
      });
    }
  }

  void _syncFromService() {
    final svc = AlertService.instance;
    _tier = svc.currentTier.clamp(1, 3);
    _remaining = svc.escalationRemaining;
    _telegramSent = svc.telegramSent;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _acknowledge() {
    AlertService.instance.acknowledge();
    Navigator.of(context).pop();
  }

  Color get _tint {
    if (!_isCritical) return AppColors.caution;
    if (_telegramSent || _tier >= 3) return AppColors.warning;
    if (_tier >= 2) return const Color(0xFFB91C1C);
    return AppColors.warning;
  }

  ({IconData icon, String headline, String subtext}) get _content {
    if (_telegramSent && _isCritical) {
      final count = AlertService.instance.lastNotifiedCount;
      return (
        icon: Icons.mark_email_read_outlined,
        headline: 'Contact Notified',
        subtext: count > 0
            ? 'Your emergency contacts have been alerted ($count notified). Please check on your child immediately.'
            : 'No emergency contacts are linked yet, so no one else was notified. Please check on your child immediately, and add a contact from the Family page.',
      );
    }

    switch (widget.event.reason) {
      case AlertReason.heat:
        if (_tier >= 2) {
          return (
            icon: Icons.local_fire_department,
            headline: 'Heat Still Critical!',
            subtext: 'Check on child now — emergency contacts will be notified soon.',
          );
        }
        return (
          icon: Icons.sentiment_very_dissatisfied,
          headline: 'Temperature Critical!',
          subtext: 'Check on child!',
        );
      case AlertReason.buckleReminder:
        return (
          icon: Icons.link_off,
          headline: 'Buckle Unlatched!',
          subtext: 'Ensure buckle is securely latched before proceeding.',
        );
      case AlertReason.lowBattery:
        return (
          icon: Icons.battery_alert,
          headline: 'Battery Low',
          subtext: 'Check the device charge.',
        );
      case AlertReason.leftBehind:
        if (_tier >= 2) {
          return (
            icon: Icons.warning_amber_rounded,
            headline: 'Child Still in Car',
            subtext: widget.childName != null
                ? 'URGENT — check on ${widget.childName} now.'
                : 'URGENT — check on your child now.',
          );
        }
        return (
          icon: Icons.event_seat,
          headline: 'Child Still in Car',
          subtext: widget.childName != null
              ? 'Check on ${widget.childName}.'
              : 'Check on your child.',
        );
      case AlertReason.none:
        return (
          icon: Icons.event_seat,
          headline: 'Alert',
          subtext: '',
        );
    }
  }

  bool get _showCountdown =>
      _isCritical && !_telegramSent && _tier >= 3;

  @override
  Widget build(BuildContext context) {
    final c = _content;
    final total = AlertService.instance.totalSecondsFor(widget.event.reason);
    final progress = total <= 0
        ? 0.0
        : (_remaining.inSeconds / total).clamp(0.0, 1.0);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_tint.withValues(alpha: 0.55), Colors.white],
              stops: const [0.0, 0.55],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  if (!_showCountdown && !_telegramSent) ...[
                    Icon(c.icon, size: 96, color: AppColors.navy),
                    const SizedBox(height: 28),
                  ],
                  if (_telegramSent) ...[
                    Icon(c.icon, size: 96, color: AppColors.warning),
                    const SizedBox(height: 28),
                  ],
                  Text(
                    c.headline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _tier >= 2 && _isCritical
                          ? AppColors.warning
                          : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    c.subtext,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_showCountdown) ...[
                    const SizedBox(height: 36),
                    const Text(
                      'EMERGENCY CONTACTS WILL BE NOTIFIED IN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _CountdownRing(
                      progress: progress,
                      remaining: _remaining,
                      color: AppColors.warning,
                    ),
                  ],
                  const Spacer(flex: 3),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _acknowledge,
                      child: Text(
                        _telegramSent ? 'I Understand' : 'Acknowledge',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Countdown ring ────────────────────────────────────────────────────────────

/// Escalation countdown dial.
///
/// Uses a custom painter rather than [CircularProgressIndicator] so the arc can
/// sweep smoothly between ticks — the service only updates once per second, so
/// a stock indicator visibly steps. The value is interpolated across each
/// second, and the numeral sits on a raised inner disc so the ring reads as a
/// distinct outer layer rather than a border around text.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({
    required this.progress,
    required this.remaining,
    required this.color,
  });

  final double progress;
  final Duration remaining;
  final Color color;

  static const _stroke = 12.0;

  @override
  Widget build(BuildContext context) {
    final size =
        (MediaQuery.of(context).size.width * 0.60).clamp(212.0, 248.0);

    final secs = remaining.inSeconds;
    final underMinute = secs < 60;
    final value = underMinute
        ? '$secs'
        : '${(secs ~/ 60).toString().padLeft(2, '0')}:'
            '${(secs % 60).toString().padLeft(2, '0')}';

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: progress, end: progress),
        duration: const Duration(milliseconds: 950),
        curve: Curves.linear,
        builder: (context, animated, _) {
          return CustomPaint(
            painter: _RingPainter(
              progress: animated,
              color: color,
              stroke: _stroke,
            ),
            child: Center(
              child: Container(
                width: size - (_stroke * 2) - 26,
                height: size - (_stroke * 2) - 26,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.10),
                      blurRadius: 22,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: underMinute ? 64 : 50,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        height: 1.0,
                        letterSpacing: -1.5,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      underMinute ? 'SECONDS' : 'REMAINING',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track — the full dial, so remaining time reads against the whole.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.14),
    );

    if (progress <= 0) return;

    // Depleting arc — starts at 12 o'clock, sweeps clockwise.
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.stroke != stroke;
}
