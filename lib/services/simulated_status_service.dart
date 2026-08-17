import 'dart:math';

import '../models/child.dart';
import '../models/seat_status.dart';

/// Deterministic always-SAFE telemetry for simulated (non-hardware) children.
///
/// Values are hashed from [childId] and cached so StreamBuilder rebuilds do
/// not re-roll battery/temperature.
class SimulatedStatusService {
  SimulatedStatusService._();
  static final instance = SimulatedStatusService._();

  final Map<String, SeatStatus> _cache = {};

  /// True when this child should read the shared `live` row.
  ///
  /// Prefers `hardware_linked`. If the column is not backfilled yet, the
  /// earliest child in [familyChildren] (created_at order) is treated as
  /// hardware so the physical seat is not hidden.
  bool usesHardware(Child child, List<Child> familyChildren) {
    if (child.hardwareLinked) return true;
    if (familyChildren.any((c) => c.hardwareLinked)) return false;
    return familyChildren.isNotEmpty && familyChildren.first.id == child.id;
  }

  SeatStatus resolve(
    Child child,
    List<Child> familyChildren,
    SeatStatus live,
  ) {
    if (usesHardware(child, familyChildren)) return live;
    return forChild(child.id);
  }

  SeatStatus forChild(String childId) {
    return _cache.putIfAbsent(childId, () {
      final rng = Random(childId.hashCode);
      return SeatStatus(
        temperature: 22.0 + rng.nextInt(41) / 10.0,
        present: true,
        buckled: true,
        distanceNear: true,
        battery: 70 + rng.nextInt(26),
        carMoving: true,
      );
    });
  }
}
