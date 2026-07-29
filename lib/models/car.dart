import 'package:flutter/material.dart';

class Car {
  final String id;
  final String familyId;
  final String name;
  final String color; // hex string, e.g. '#3B74BC'
  final String? plateNumber;

  const Car({
    required this.id,
    required this.familyId,
    required this.name,
    required this.color,
    this.plateNumber,
  });

  factory Car.fromMap(Map<String, dynamic> m) => Car(
        id: m['id'].toString(),
        familyId: m['family_id'].toString(),
        name: m['name'] as String? ?? '',
        color: m['color'] as String? ?? '#3B74BC',
        plateNumber: m['plate_number'] as String?,
      );
}

/// Parses a '#RRGGBB' string into a Color; falls back to app accent blue
/// on any malformed input.
Color carColorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length != 6) return const Color(0xFF3B74BC);
  final value = int.tryParse('FF$cleaned', radix: 16);
  return value != null ? Color(value) : const Color(0xFF3B74BC);
}
