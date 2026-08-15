import 'package:flutter/foundation.dart';

import '../core/constants.dart';

enum SeatSeverity { safe, caution, warning }

enum AlertReason { none, leftBehind, heat, buckleReminder, lowBattery }

@immutable
class SeatStatus {
  final double temperature;
  final bool present;
  final bool buckled;
  final bool distanceNear;
  final int battery;
  final DateTime? updatedAt;
  final String? placeName;
  final bool carMoving;

  const SeatStatus({
    required this.temperature,
    required this.present,
    required this.buckled,
    required this.distanceNear,
    required this.battery,
    this.updatedAt,
    this.placeName,
    this.carMoving = true,
  });

  factory SeatStatus.empty() => const SeatStatus(
        temperature: 0, present: false, buckled: false,
        distanceNear: false, battery: 0,
      );

  factory SeatStatus.fromMap(Map<String, dynamic> map) => SeatStatus(
        temperature: _asDouble(map['temperature']),
        present: _asBool(map['present']),
        buckled: _asBool(map['buckled']),
        distanceNear: _asBool(map['distance_near']),
        battery: _readBatteryPercent(map),
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'].toString())
            : null,
        placeName: map['place_name'] as String?,
        // Default true (fail-safe: alert) if the column is missing/null,
        // e.g. before the firmware sends it.
        carMoving: _asBool(map['car_moving'], true),
      );

  /// Firmware sends `battery` as an int and `battery_voltage` as a float.
  /// PostgREST `numeric` columns often arrive as strings — never drop those to 0.
  static int _readBatteryPercent(Map<String, dynamic> map) {
    final pct = _asInt(map['battery']);
    if (pct > 0) return pct.clamp(0, 100);
    final volts = _asDouble(map['battery_voltage']);
    if (volts <= 0) return pct.clamp(0, 100);
    // Same map as firmware voltageToPercentage (3.0 V empty → 4.2 V full).
    if (volts <= 3.0) return 0;
    if (volts >= 4.2) return 100;
    return (((volts - 3.0) / 1.2) * 100).round().clamp(0, 100);
  }

  static double _asDouble(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int _asInt(dynamic value, [int fallback = 0]) {
    if (value is num) return value.round();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.round() ?? fallback;
    }
    return fallback;
  }

  static bool _asBool(dynamic value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == 'true' || v == 't' || v == '1') return true;
      if (v == 'false' || v == 'f' || v == '0') return false;
    }
    return fallback;
  }

  // Severity depends on WHICH indicator fails, not how many. Warning wins over caution.
  SeatSeverity get severity {
    const lowBattery = 20;        // %
    if (present && !distanceNear) return SeatSeverity.warning;              // left-behind
    if (present && temperature > kHeatThresholdC) return SeatSeverity.warning; // heat
    if (present && !buckled && distanceNear) return SeatSeverity.caution;    // buckle reminder
    if (battery < lowBattery) return SeatSeverity.caution;                   // low battery
    return SeatSeverity.safe;
  }

  AlertReason get reason {
    const lowBatteryPct = 20;
    if (present && !distanceNear) return AlertReason.leftBehind;
    if (present && temperature > kHeatThresholdC) return AlertReason.heat;
    if (present && !buckled && distanceNear) return AlertReason.buckleReminder;
    if (battery < lowBatteryPct) return AlertReason.lowBattery;
    return AlertReason.none;
  }
}
