import 'package:flutter/material.dart';

/// Colored circle showing a contact's initials, deterministically
/// colored from their name so the same person always gets the same
/// color between app opens. Used where a real photo isn't available
/// (e.g. emergency contacts).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.radius = 20});

  final String name;
  final double radius;

  static const List<Color> _palette = [
    Color(0xFF3B74BC), // Blue
    Color(0xFF56B337), // Green
    Color(0xFFE08D3C), // Orange
    Color(0xFF7C5CBF), // Purple
    Color(0xFFD6608A), // Pink
    Color(0xFF1E9C8B), // Teal
    Color(0xFF0F2D54), // Navy
  ];

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color get _color {
    if (name.trim().isEmpty) return _palette.first;
    final hash =
        name.trim().toLowerCase().codeUnits.fold<int>(0, (a, b) => a + b);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _color,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}
