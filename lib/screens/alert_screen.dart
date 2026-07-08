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
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    if (widget.event.reason == AlertReason.leftBehind) {
      _remaining = AlertService.instance.escalationRemaining;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _remaining = AlertService.instance.escalationRemaining;
        });
      });
    }
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

  Color get _tint => widget.event.severity == SeatSeverity.warning
      ? AppColors.warning
      : AppColors.caution;

  ({IconData icon, String headline, String subtext}) get _content {
    switch (widget.event.reason) {
      case AlertReason.heat:
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
      case AlertReason.none:
        return (
          icon: Icons.event_seat,
          headline: 'Child Still in Car',
          subtext: widget.childName != null
              ? 'Check on ${widget.childName}.'
              : 'Check on your child.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _content;
    final isLeftBehind = widget.event.reason == AlertReason.leftBehind;

    return Scaffold(
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
                if (!isLeftBehind) ...[
                  Icon(c.icon, size: 96, color: AppColors.navy),
                  const SizedBox(height: 28),
                ],
                Text(
                  c.headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
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
                if (isLeftBehind) ...[
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
                          value: _remaining.inSeconds /
                              AlertService.escalationDelay.inSeconds,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.shade300,
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.warning),
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
                              'minutes',
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
                    child: const Text('Acknowledge'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
