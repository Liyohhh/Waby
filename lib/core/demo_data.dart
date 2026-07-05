import '../models/seat_status.dart';

/// Static demo payloads shown only for [DemoAccount.email].
class DemoChildSeed {
  const DemoChildSeed({
    required this.name,
    required this.deviceName,
    required this.dob,
    required this.weightKg,
    required this.heightCm,
    required this.status,
    required this.buckled,
    required this.near,
    required this.battery,
  });

  final String name;
  final String deviceName;
  final DateTime dob;
  final double weightKg;
  final double heightCm;
  final SeatSeverity status;
  final bool buckled;
  final bool near;
  final int battery;

  bool get present => true;
}

class DemoContactSeed {
  const DemoContactSeed({
    required this.name,
    required this.phone,
    required this.relation,
  });

  final String name;
  final String phone;
  final String relation;
}

/// Fixed demo account — credentials, profile, and seeded display data.
class DemoAccount {
  const DemoAccount._();

  static const String email = 'waby.demo@waby.app';
  static const String password = 'WabyDemo123!';
  static const String displayName = 'Mom';
  static const String familyName = 'Waby Demo Family';
  /// Invite code shown in Settings → Family Management for the demo family.
  static const String inviteCode = 'BT-8942';
  static const String profilePhone = '+60 12 345 6789';
  static const String profileRelation = 'Parent';
  static const String profileCountry = 'Malaysia';

  static final children = [
    DemoChildSeed(
      name: 'Jason Tan',
      deviceName: "Jason's Seat",
      dob: DateTime(2026, 1, 15),
      weightKg: 8.5,
      heightCm: 73,
      status: SeatSeverity.safe,
      buckled: true,
      near: true,
      battery: 88,
    ),
    DemoChildSeed(
      name: 'Nur Alysha',
      deviceName: "Alysha's Seat",
      dob: DateTime(2025, 3, 20),
      weightKg: 7.2,
      heightCm: 68,
      status: SeatSeverity.warning,
      buckled: false,
      near: false,
      battery: 15,
    ),
  ];

  static const contacts = [
    DemoContactSeed(
      name: 'Ahmad Tan',
      phone: '+60 12 987 6543',
      relation: 'Father',
    ),
  ];

  /// Header / car temperature reading for the demo dashboard.
  static const headerLive = SeatStatus(
    temperature: 23,
    present: true,
    buckled: true,
    distanceNear: true,
    battery: 88,
  );

  static DemoChildSeed? childSeedFor(String name) {
    final key = name.trim().toLowerCase();
    for (final c in children) {
      if (c.name.toLowerCase() == key) return c;
    }
    return null;
  }

  /// Demo dashboard data applies to the demo login OR any member of the demo family.
  static bool useDemoDisplay({
    required bool isDemoUser,
    required bool isDemoFamily,
  }) =>
      isDemoUser || isDemoFamily;
}
