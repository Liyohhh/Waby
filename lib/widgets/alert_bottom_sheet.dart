import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../services/alert_feedback_service.dart';
import '../services/alert_service.dart';
import '../services/push_notification_service.dart';

class _AlertSheetWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 22)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height - 4,
        size.width * 0.55,
        size.height - 14,
      )
      ..quadraticBezierTo(
        size.width * 0.80,
        size.height - 26,
        size.width,
        size.height - 14,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

Future<void> showAlertBottomSheet(
  BuildContext context, {
  required List<ActiveAlert> initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.navy.withValues(alpha: 0.42),
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => AlertBottomSheet(initial: initial),
  );
}

class AlertBottomSheet extends StatefulWidget {
  const AlertBottomSheet({super.key, required this.initial});

  final List<ActiveAlert> initial;

  @override
  State<AlertBottomSheet> createState() => _AlertBottomSheetState();
}

class _AlertBottomSheetState extends State<AlertBottomSheet> {
  late final PageController _pageController;
  late StreamSubscription<List<ActiveAlert>> _sub;
  List<ActiveAlert> _alerts = [];
  int _currentIndex = 0;

  ActiveAlert get _currentAlert => _alerts[_currentIndex];

  @override
  void initState() {
    super.initState();
    AlertService.instance.setSheetOpen(true);
    _alerts = List<ActiveAlert>.from(widget.initial);
    _pageController = PageController();
    _sub = AlertService.instance.activeAlertsStream.listen(_syncAlerts);
  }

  @override
  void dispose() {
    _sub.cancel();
    _pageController.dispose();
    unawaited(AlertFeedbackService.instance.stop());
    unawaited(PushNotificationService.instance.cancelAll());
    AlertService.instance.setSheetOpen(false);
    super.dispose();
  }

  void _syncAlerts(List<ActiveAlert> next) {
    if (!mounted) return;
    if (next.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final previousId =
        _alerts.isNotEmpty && _currentIndex < _alerts.length ? _currentAlert.alertId : null;
    final previousLength = _alerts.length;

    setState(() {
      _alerts = List<ActiveAlert>.from(next);
      if (previousId != null) {
        final keep = _alerts.indexWhere((a) => a.alertId == previousId);
        _currentIndex = keep >= 0 ? keep : 0;
      } else {
        _currentIndex = 0;
      }
      if (_currentIndex >= _alerts.length) {
        _currentIndex = _alerts.length - 1;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;

      if (_alerts.length > previousLength) {
        _pageController.animateToPage(
          _alerts.length - 1,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  Future<void> _acknowledgeCurrent() async {
    final current = _currentAlert;
    await AlertService.instance.acknowledgeAlert(current.alertId);
  }

  void _handlePageChanged(int index) {
    setState(() => _currentIndex = index);
    final current = _alerts[index];
    unawaited(
      AlertFeedbackService.instance.fire(
        current.severity,
        tier: current.tier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_alerts.isEmpty) return const SizedBox.shrink();
    final current = _currentAlert;
    final currentColor = severityColorOf(current.severity);
    final heightFactor =
        current.severity == AlertSeverity.caution ? 0.45 : 0.70;

    return PopScope(
      canPop: current.severity == AlertSeverity.caution,
      onPopInvokedWithResult: (didPop, result) {},
      child: SafeArea(
        top: false,
        child: Padding(
          padding: MediaQuery.viewInsetsOf(context),
          child: Container(
            height: MediaQuery.sizeOf(context).height * heightFactor,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey(current.severity),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 150,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipPath(
                                  clipper: _AlertSheetWaveClipper(),
                                  child: ColoredBox(color: currentColor),
                                ),
                              ),
                              Positioned.fill(
                                child: ClipPath(
                                  clipper: _AlertSheetWaveClipper(),
                                  child: CustomPaint(
                                    painter: _InnerWavePainter(currentColor),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: GestureDetector(
                                    onVerticalDragUpdate:
                                        current.severity == AlertSeverity.caution
                                            ? (details) {
                                                if (details.delta.dy > 60) {
                                                  Navigator.of(context).pop();
                                                }
                                              }
                                            : null,
                                    child: Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.55),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 40,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: _SeverityPill(
                                    severity: current.severity,
                                    whiteVariant: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -36),
                          child: Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: severityHaloOf(current.severity),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _iconForAlertType(current.alertType),
                                    size: 30,
                                    color: currentColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _alerts.length,
                    onPageChanged: _handlePageChanged,
                    itemBuilder: (_, i) => _AlertPageContent(alert: _alerts[i]),
                  ),
                ),
                if (_alerts.length > 1) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_alerts.length, (i) {
                      final active = i == _currentIndex;
                      return GestureDetector(
                        onTap: () => _pageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        ),
                        child: Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active ? currentColor : const Color(0xFFD9D9D9),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _acknowledgeCurrent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Acknowledge'),
                    ),
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

class _SeverityPill extends StatelessWidget {
  const _SeverityPill({
    required this.severity,
    this.whiteVariant = false,
  });

  final AlertSeverity severity;
  final bool whiteVariant;

  @override
  Widget build(BuildContext context) {
    final color = severityColorOf(severity);
    final bg = whiteVariant
        ? Colors.white.withValues(alpha: 0.18)
        : color.withValues(alpha: 0.12);
    final dot = whiteVariant ? Colors.white : color;
    final textColor = whiteVariant ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            switch (severity) {
              AlertSeverity.caution => 'CAUTION',
              AlertSeverity.warning => 'WARNING',
              AlertSeverity.critical => 'CRITICAL',
            },
            style: GoogleFonts.poppins(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertPageContent extends StatelessWidget {
  const _AlertPageContent({required this.alert});

  final ActiveAlert alert;

  @override
  Widget build(BuildContext context) {
    final color = severityColorOf(alert.severity);
    final title = switch (alert.alertType) {
      'heat' => 'Heat rising',
      'left_behind' => 'Child left in car',
      'buckle' => 'Buckle unlatched',
      _ => 'Alert'
    };
    final hint = switch (alert.alertType) {
      'heat' => 'Move your child now and cool the seat area.',
      'left_behind' => 'Return to the vehicle and check your child immediately.',
      'buckle' => 'Secure the buckle before continuing your trip.',
      _ => 'Check on your child now.'
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            alert.detail,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.hint,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (alert.severity != AlertSeverity.caution) ...[
                  _PulseHalo(
                    size: 192,
                    color: color,
                    duration: alert.severity == AlertSeverity.critical
                        ? const Duration(milliseconds: 800)
                        : const Duration(milliseconds: 2000),
                  ),
                  _PulseHalo(
                    size: 212,
                    color: color,
                    duration: alert.severity == AlertSeverity.critical
                        ? const Duration(milliseconds: 800)
                        : const Duration(milliseconds: 2000),
                  ),
                ],
                _CountdownRing(
                  key: ValueKey(alert.alertId),
                  alertId: alert.alertId,
                  startedAt: alert.startedAt,
                  totalSeconds: alert.totalSeconds,
                  color: color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color severityColorOf(AlertSeverity severity) {
  switch (severity) {
    case AlertSeverity.caution:
      return AppColors.caution;
    case AlertSeverity.warning:
      return AppColors.warning;
    case AlertSeverity.critical:
      return AppColors.critical;
  }
}

Color severityHaloOf(AlertSeverity severity) =>
    severityColorOf(severity).withValues(alpha: 0.10);

class _PulseHalo extends StatefulWidget {
  const _PulseHalo({
    required this.size,
    required this.color,
    required this.duration,
  });

  final double size;
  final Color color;
  final Duration duration;

  @override
  State<_PulseHalo> createState() => _PulseHaloState();
}

class _PulseHaloState extends State<_PulseHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final scale = lerpDouble(1.0, 1.15, t) ?? 1.0;
        final opacity = lerpDouble(0.22, 0.0, t) ?? 0.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class _InnerWavePainter extends CustomPainter {
  const _InnerWavePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.70)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.83,
        size.width * 0.58,
        size.height * 0.74,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.63,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _InnerWavePainter oldDelegate) =>
      oldDelegate.color != color;
}

IconData _iconForAlertType(String alertType) {
  switch (alertType) {
    case 'heat':
      return Icons.thermostat_rounded;
    case 'left_behind':
      return Icons.child_care_rounded;
    case 'buckle':
      return Icons.link_off_rounded;
    default:
      return Icons.warning_amber_rounded;
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({
    super.key,
    required this.alertId,
    required this.startedAt,
    required this.totalSeconds,
    required this.color,
  });

  final String alertId;
  final DateTime startedAt;
  final int totalSeconds;
  final Color color;

  static const _stroke = 12.0;

  @override
  Widget build(BuildContext context) {
    final size =
        (MediaQuery.sizeOf(context).width * 0.54).clamp(196.0, 236.0);
    final elapsed = DateTime.now().difference(startedAt).inMilliseconds / 1000.0;
    final remaining =
        (totalSeconds - elapsed).clamp(0.0, totalSeconds.toDouble());
    final progress = totalSeconds <= 0 ? 0.0 : remaining / totalSeconds;
    final secs = remaining.ceil();
    final underMinute = secs < 60;
    final value = underMinute
        ? '$secs'
        : '${(secs ~/ 60).toString().padLeft(2, '0')}:'
            '${(secs % 60).toString().padLeft(2, '0')}';

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: progress, end: 0.0),
        duration: Duration(milliseconds: (remaining * 1000).round()),
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
                        fontSize: underMinute ? 58 : 46,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        height: 1.0,
                        letterSpacing: -1.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
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

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.14),
    );

    if (progress <= 0) return;

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
