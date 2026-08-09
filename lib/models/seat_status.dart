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
        temperature: (map['temperature'] as num?)?.toDouble() ?? 0,
        present: map['present'] as bool? ?? false,
        buckled: map['buckled'] as bool? ?? false,
        distanceNear: map['distance_near'] as bool? ?? false,
        battery: (map['battery'] as num?)?.toInt() ?? 0,
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'].toString())
            : null,
        placeName: map['place_name'] as String?,
        // Default true (fail-safe: alert) if the column is missing/null,
        // e.g. before the firmware sends it.
        carMoving: map['car_moving'] as bool? ?? true,
      );

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
