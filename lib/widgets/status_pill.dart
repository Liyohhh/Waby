import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Semantic tone for a [StatusPill]. Drives the colour; callers never
/// hard-code hex values.
enum StatusTone { good, bad, neutral }

extension _ToneColor on StatusTone {
  Color get color => switch (this) {
        StatusTone.good    => AppColors.safe,    // #56B337
        StatusTone.bad     => AppColors.warning, // #C2291D
        StatusTone.neutral => AppColors.accent,  // #3B74BC
      };
}

/// A quiet tonal chip that colours itself by [tone] rather than the
/// enclosing card's overall status.
///
/// Background is the tone colour at 12 % opacity; icon and label
/// use the full-strength tone colour (label is navy for legibility).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData  icon;
  final String    label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = tone.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
