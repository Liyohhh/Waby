import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

/// Acknowledge button whose lighter fill drains from full to empty over
/// [duration], mirroring the escalation countdown. Tapping before it empties
/// calls [onAcknowledge]; reaching zero without a tap fires [onExpired].
class DrainingAckButton extends StatefulWidget {
  const DrainingAckButton({
    super.key,
    required this.label,
    required this.duration,
    required this.onAcknowledge,
    this.onExpired,
    this.baseColor = AppColors.safe,
    this.initialFraction = 1.0, // 1.0 = full window remaining
    this.showSeconds = false,
  });

  final String label;
  final Duration duration;
  final VoidCallback onAcknowledge;
  final VoidCallback? onExpired;
  final Color baseColor;
  final double initialFraction;
  final bool showSeconds;

  @override
  State<DrainingAckButton> createState() => _DrainingAckButtonState();
}

class _DrainingAckButtonState extends State<DrainingAckButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.initialFraction,
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && !_done) {
          _done = true;
          widget.onExpired?.call();
        }
      });
    _controller.reverse(from: widget.initialFraction); // drain toward 0
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_done) return;
    _done = true;
    _controller.stop();
    widget.onAcknowledge();
  }

  @override
  Widget build(BuildContext context) {
    // Lighter tint of the base colour = the depleting "time remaining" layer.
    final lighter = Color.lerp(widget.baseColor, Colors.white, 0.38)!;
    return GestureDetector(
      onTap: _handleTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: Stack(
            children: [
              // Solid base (the "empty" state underneath).
              Positioned.fill(child: ColoredBox(color: widget.baseColor)),
              // Draining lighter layer — width = remaining fraction, anchored left.
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _controller.value.clamp(0.0, 1.0),
                    child: ColoredBox(color: lighter),
                  ),
                ),
              ),
              // Label (always full opacity, on top).
              Positioned.fill(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final secs =
                          (_controller.value * widget.duration.inSeconds)
                              .ceil();
                      final text = widget.showSeconds
                          ? '${widget.label}  (${secs}s)'
                          : widget.label;
                      return Text(
                        text,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
