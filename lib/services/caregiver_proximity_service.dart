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

  bool _started = false;
  bool _everSeenSeat = false;
  bool _scanning = false;
  DateTime? _lastSeenAt;
  bool? _lastPersistedNear;
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
    unawaited(FlutterBluePlus.adapterState.first);
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        unawaited(_scanBurst());
      }
    });

    _scanTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_scanBurst());
    });
    unawaited(_scanBurst());
  }

  void stop() {
    _scanTimer?.cancel();
    _scanSub?.cancel();
    _scanTimer = null;
    _scanSub = null;
    _started = false;
  }

  Future<void> _scanBurst() async {
    if (_scanning) return;
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      _checkLost();
      return;
    }
    _scanning = true;
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 2),
        androidUsesFineLocation: true,
      );
    } catch (_) {
      // Permission denied or adapter off — do not invent Far.
    } finally {
      _scanning = false;
      _checkLost();
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
    final current = isNear.value;
    bool next;
    if (current == true) {
      next = rssi > kBleRssiFarDbm;
    } else if (current == false) {
      next = rssi >= kBleRssiNearDbm;
    } else {
      next = rssi >= kBleRssiNearDbm;
    }
    _setNear(next);
  }

  void _checkLost() {
    if (!_everSeenSeat) return;
    final seen = _lastSeenAt;
    if (seen == null) return;
    if (DateTime.now().difference(seen) >= kBleLostAfter) {
      lastRssi.value = null;
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
