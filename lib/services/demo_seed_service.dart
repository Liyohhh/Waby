import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/demo_data.dart';
import 'auth_service.dart';
import 'contact_service.dart';
import 'device_service.dart';
import 'family_service.dart';

/// Seeds Supabase rows for the shared demo account (idempotent).
class DemoSeedService {
  final SupabaseClient _db = Supabase.instance.client;
  final AuthService _auth = AuthService();

  Future<void> seedIfNeeded() async {
    if (!_auth.isDemoUser) return;
    final uid = _auth.currentUser?.id;
    if (uid == null) return;

    await _ensureFamily();
    await _ensureProfile();
    await _ensureChildren(uid);
    await _ensureLive();
    await _ensureContacts();
  }

  Future<void> _ensureFamily() async {
    final familyId = await FamilyService().myFamilyId();
    if (familyId != null) return;
    await FamilyService().createFamily(DemoAccount.familyName);
  }

  Future<void> _ensureProfile() async {
    try {
      await _auth.updateProfile(
        fullName: DemoAccount.displayName,
        phone: DemoAccount.profilePhone,
        relation: DemoAccount.profileRelation,
        country: DemoAccount.profileCountry,
      );
    } catch (_) {}
  }

  Future<void> _ensureChildren(String uid) async {
    try {
      final rows = await _db
          .from('children')
          .select('name')
          .eq('user_id', uid);
      final existing = rows.map((r) => r['name'] as String).toSet();
      final deviceService = DeviceService();

      for (final seed in DemoAccount.children) {
        if (existing.contains(seed.name)) continue;
        await deviceService.addDeviceWithChild(
          deviceName: seed.deviceName,
          childName: seed.name,
          dob: seed.dob,
          gender: seed.gender,
          weightKg: seed.weightKg,
          heightCm: seed.heightCm,
        );
      }
    } catch (_) {}
  }

  Future<void> _ensureLive() async {
    try {
      await _db.from('live').upsert({
        'id': 1,
        'temperature': DemoAccount.headerLive.temperature,
        'present': DemoAccount.headerLive.present,
        'buckled': DemoAccount.headerLive.buckled,
        'distance_near': DemoAccount.headerLive.distanceNear,
        'battery': DemoAccount.headerLive.battery,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> _ensureContacts() async {
    try {
      final existing = await _db.from('contacts').select('name');
      final names = existing.map((r) => r['name'] as String).toSet();
      final service = ContactService();

      for (final seed in DemoAccount.contacts) {
        if (names.contains(seed.name)) continue;
        await service.addContact(
          name: seed.name,
          phone: seed.phone,
          relation: seed.relation,
        );
      }
    } catch (_) {}
  }
}
