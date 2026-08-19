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
  final double? batteryVoltage;
  final DateTime? updatedAt;
  final String? placeName;
  final bool carMoving;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracyM;

  const SeatStatus({
    required this.temperature,
    required this.present,
    required this.buckled,
    required this.distanceNear,
    required this.battery,
    this.batteryVoltage,
    this.updatedAt,
    this.placeName,
    this.carMoving = true,
    this.latitude,
    this.longitude,
    this.gpsAccuracyM,
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
        battery: _readBatteryPercent(map['battery']),
        batteryVoltage: _asNullableDouble(map['battery_voltage']),
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'].toString())
            : null,
        placeName: map['place_name'] as String?,
        // Default true (fail-safe: alert) if the column is missing/null,
        // e.g. before the firmware sends it.
        carMoving: _asBool(map['car_moving'], true),
        latitude: _asNullableDouble(map['latitude']),
        longitude: _asNullableDouble(map['longitude']),
        gpsAccuracyM: _asNullableDouble(map['gps_accuracy_m']),
      );

  /// Firmware sends `0.0, 0.0` when the NEO-6M has no fix.
  bool get hasGpsFix {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return false;
    return lat != 0 || lng != 0;
  }

  String get gpsLabel {
    if (!hasGpsFix) return 'No GPS fix';
    final lat = latitude!;
    final lng = longitude!;
    final latHem = lat >= 0 ? 'N' : 'S';
    final lngHem = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(4)}° $latHem, ${lng.abs().toStringAsFixed(4)}° $lngHem';
  }

  SeatStatus copyWith({
    double? temperature,
    bool? present,
    bool? buckled,
    bool? distanceNear,
    int? battery,
    double? batteryVoltage,
    DateTime? updatedAt,
    String? placeName,
    bool? carMoving,
    double? latitude,
    double? longitude,
    double? gpsAccuracyM,
  }) {
    return SeatStatus(
      temperature: temperature ?? this.temperature,
      present: present ?? this.present,
      buckled: buckled ?? this.buckled,
      distanceNear: distanceNear ?? this.distanceNear,
      battery: battery ?? this.battery,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      updatedAt: updatedAt ?? this.updatedAt,
      placeName: placeName ?? this.placeName,
      carMoving: carMoving ?? this.carMoving,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracyM: gpsAccuracyM ?? this.gpsAccuracyM,
    );
  }

  /// Firmware always PATCHes `battery` as a 0–100 int. Postgres/`numeric`
  /// (and some Realtime payloads) may deliver it as a string — parse, never
  /// `as num?`. Voltage is display-only and must not replace this percent.
  static int _readBatteryPercent(dynamic value) {
    if (value == null) return 0;
    final parsed = num.tryParse(value.toString())?.round();
    if (parsed == null) return 0;
    return parsed.clamp(0, 100);
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    return num.tryParse(value.toString())?.toDouble();
  }

  static double _asDouble(dynamic value, [double fallback = 0]) {
    return _asNullableDouble(value) ?? fallback;
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
    if (present && temperature >= kHeatThresholdC) return SeatSeverity.warning; // heat
    if (present && !buckled && distanceNear) return SeatSeverity.caution;    // buckle reminder
    if (battery < lowBattery) return SeatSeverity.caution;                   // low battery
    return SeatSeverity.safe;
  }

  AlertReason get reason {
    const lowBatteryPct = 20;
    if (present && !distanceNear) return AlertReason.leftBehind;
    if (present && temperature >= kHeatThresholdC) return AlertReason.heat;
    if (present && !buckled && distanceNear) return AlertReason.buckleReminder;
    if (battery < lowBatteryPct) return AlertReason.lowBattery;
    return AlertReason.none;
  }
}
