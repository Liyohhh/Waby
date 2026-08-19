import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../models/seat_status.dart';

/// Measures BLE RSSI of the ESP32 seat beacon (`kBleSeatName`) to decide
/// whether the caregiver (phone) is Near or Far.
///
/// Until the seat has been seen at least once this session, [applyTo] leaves
/// `live.distance_near` unchanged so an un-flashed ESP32 does not false-alarm
/// left-behind.
class CaregiverProximityService {
  CaregiverProximityService._();
  static final instance = CaregiverProximityService._();

  final ValueNotifier<bool?> isNear = ValueNotifier<bool?>(null);
  final ValueNotifier<int?> lastRssi = ValueNotifier<int?>(null);
  final ValueNotifier<int?> smoothedRssi = ValueNotifier<int?>(null);

  bool _started = false;
  bool _everSeenSeat = false;
  DateTime? _lastSeenAt;
  bool? _lastPersistedNear;
  final List<int> _rssiWindow = [];
  static const int _rssiWindowSize = 11;
  bool? _pendingNear;
  int _pendingCount = 0;
  static const int _requiredConsecutive = 2;
  Timer? _scanTimer;
  StreamSubscription<List<ScanResult>>? _scanSub;

  SeatStatus applyTo(SeatStatus status) {
    if (!_everSeenSeat || isNear.value == null) return status;
    return status.copyWith(distanceNear: isNear.value);
  }

  Future<void> start() async {
    if (_started) return;
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    _started = true;

    _scanSub = FlutterBluePlus.scanResults.listen(_onScanResults);
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        unawaited(_ensureScanning());
      }
    });

    // One long-lived scan + a light watchdog. We do NOT stop/start every few
    // seconds (Android throttles that). The watchdog only restarts the scan
    // if it has actually stopped, and expires stale reads.
    _scanTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_ensureScanning());
      _checkLost();
    });
    unawaited(_ensureScanning());
  }

  void stop() {
    _scanTimer?.cancel();
    _scanSub?.cancel();
    _scanTimer = null;
    _scanSub = null;
    _started = false;
    unawaited(FlutterBluePlus.stopScan());
  }

  Future<void> _ensureScanning() async {
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) return;
    if (FlutterBluePlus.isScanningNow) return; // already scanning, leave it
    try {
      await FlutterBluePlus.startScan(
        continuousUpdates: true, // keep receiving RSSI from the same beacon
        continuousDivisor: 1, // emit on every advertisement packet
        androidUsesFineLocation: true,
        // no timeout: one persistent scan instead of bursts
      );
    } catch (_) {
      // Permission denied / adapter off — do not invent Far.
    }
  }

  void _onScanResults(List<ScanResult> results) {
    ScanResult? match;
    for (final result in results) {
      if (_isSeat(result)) {
        match = result;
        break;
      }
    }
    if (match == null) return;
    _everSeenSeat = true;
    _lastSeenAt = DateTime.now();
    lastRssi.value = match.rssi;
    _applyRssi(match.rssi);
  }

  bool _isSeat(ScanResult result) {
    final names = <String>[
      result.device.platformName,
      result.advertisementData.advName,
    ];
    return names.any(
      (name) => name == kBleSeatName || name.toLowerCase().contains('waby'),
    );
  }

  void _applyRssi(int rssi) {
    _rssiWindow.add(rssi);
    if (_rssiWindow.length > _rssiWindowSize) _rssiWindow.removeAt(0);

    final sorted = List<int>.from(_rssiWindow)..sort();
    final median = sorted[sorted.length ~/ 2];
    smoothedRssi.value = median;

    final current = isNear.value;
    bool next;
    if (current == true) {
      next = median > kBleRssiFarDbm;
    } else if (current == false) {
      next = median >= kBleRssiNearDbm;
    } else {
      next = median >= kBleRssiNearDbm;
    }

    if (next == current) {
      _pendingNear = null;
      _pendingCount = 0;
      return;
    }

    if (_pendingNear == next) {
      _pendingCount++;
    } else {
      _pendingNear = next;
      _pendingCount = 1;
    }

    if (_pendingCount >= _requiredConsecutive) {
      _setNear(next);
      _pendingNear = null;
      _pendingCount = 0;
    }
  }

  void _checkLost() {
    if (!_everSeenSeat) return;
    final seen = _lastSeenAt;
    if (seen == null) return;
    if (DateTime.now().difference(seen) >= kBleLostAfter) {
      lastRssi.value = null;
      smoothedRssi.value = null;
      _rssiWindow.clear();
      _pendingNear = null;
      _pendingCount = 0;
      _setNear(false);
    }
  }

  void _setNear(bool near) {
    if (isNear.value != near) {
      isNear.value = near;
    }
    if (_lastPersistedNear == near) return;
    _lastPersistedNear = near;
    unawaited(_persist(near));
  }

  Future<void> _persist(bool near) async {
    try {
      await Supabase.instance.client
          .from('live')
          .update({'distance_near': near}).eq('id', 1);
    } catch (_) {}
  }
}
