import 'dart:async';
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
      return (
        icon: Icons.mark_email_read_outlined,
        headline: 'Contact Notified',
        subtext:
            'Your emergency contacts have been alerted. Please check on your child immediately.',
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
                    const SizedBox(height: 40),
                    const Text(
                      'Your family members will\nbe notified in',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.warning),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(_remaining.inSeconds ~/ 60).toString().padLeft(2, '0')}:'
                                '${(_remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                              const Text(
                                'remaining',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
