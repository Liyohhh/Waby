import 'package:flutter/material.dart';

class ContactStatusBadge extends StatelessWidget {
  const ContactStatusBadge({super.key, required this.linked});

  final bool linked;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = linked
        ? ('Linked', const Color(0xFF56B337))
        : ('Not linked', const Color(0xFF8A8A8A));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
